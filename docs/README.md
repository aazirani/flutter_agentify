# Flutter Agentify docs

These pages explain how a Flutter Agentify app works and how to build one. They are plain Markdown, so they read the same on GitHub and in an editor.

## Reading order

1. [Getting started](getting-started.md): create a project, run it, connect a model and chat.
2. [Overview](concepts/overview.md): the idea in one page.
3. [Build your first feature](tutorial/build-your-first-feature.md): a notes feature by hand, with every file.
4. [Build with a coding agent](tutorial/build-with-a-coding-agent.md): the same feature, built by an agent.
5. The concepts, in the order below. Each page says what a part is, why it exists, and where its reference lives.
6. The guides, when you have a task at hand.
7. The [reference](reference/README.md), when you need an exact rule, flag or limit.

## Tutorials

| Page | What it covers |
|---|---|
| [Build your first feature](tutorial/build-your-first-feature.md) | A notes feature in an empty project, by hand: table, actions, screen, tests. |
| [Build with a coding agent](tutorial/build-with-a-coding-agent.md) | The prompt to paste, what the agent does, and what to check in its report. |

## Concepts

| Page | What it covers |
|---|---|
| [Overview](concepts/overview.md) | One action, three callers: the UI, the assistant and the command line. |
| [Actions](concepts/actions.md) | The one place where the app changes data. |
| [App context](concepts/app-context.md) | What the assistant sees of the screen. |
| [Approval and receipts](concepts/approval-and-receipts.md) | Which actions ask first, and how the person sees what changed. |
| [Agent loop](concepts/agent-loop.md) | What happens between a message and a reply. |
| [Model providers](concepts/model-providers.md) | How the app reaches a model, and where keys live. |
| [Memory](concepts/memory.md) | Conversations and saved facts. |
| [Architecture](concepts/architecture.md) | The layers, and where new code goes. |
| [Quality gate](concepts/quality-gate.md) | `tool/check.sh`, the lint rules, the doctor and the parity test. |
| [Coding agents](concepts/coding-agents.md) | `AGENTS.md`, skills and learnings, and how they keep an agent on track. |

## Guides

| Page | What it covers |
|---|---|
| [Choose a starting point](guides/choose-a-starting-point.md) | `example` or `empty`, and dropping the example later. |
| [Connect a model](guides/connect-a-model.md) | Local servers, hosted APIs, a phone and a computer, web. |
| [Choose where the model runs](guides/choose-where-the-model-runs.md) | A model server, a model inside the app, or both. |
| [Ship without user keys](guides/ship-without-user-keys.md) | A proxy that holds the key, with the Custom preset. |
| [Rebrand](guides/rebrand.md) | The name, the application id and the icons after setup. |
| [Add or remove a language](guides/add-a-language.md) | The one list of languages, a language file and its font. |
| [Customize the assistant](guides/customize-the-assistant.md) | Its instructions, its texts, its look. |
| [Upgrade](guides/upgrade.md) | Bringing the newest framework into a project. |
| [Platforms](guides/platforms.md) | What each platform needs, and what has been built. |
| [Troubleshooting](guides/troubleshooting.md) | Setup refusals, stale code, lint rules, reaching the model. |

## Reference

[reference/README.md](reference/README.md) links to every reference page.

Search the framework's reference pages from a terminal:

```bash
dart run flutter_agentify_core:docs --query "needs approval"
```
