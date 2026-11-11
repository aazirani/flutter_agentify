# Coding agents

A coding agent, such as Claude Code, Codex or Gemini CLI, can build features in a Flutter Agentify app. The repo holds the files that tell it how.

## The files

- **[`AGENTS.md`](../../AGENTS.md).** The entry point. It holds the rules, how to add a feature, and the list of skills. `CLAUDE.md` and `GEMINI.md` hold only `@AGENTS.md`, so every agent reads the same file.
- **Skills, in [`.agents/skills/`](../../.agents/skills/).** One folder per topic, each with a `SKILL.md`. The agent loads the one that fits the task, such as `adding-a-feature` or `storing-data`. `.claude/skills` links to the same folder.
- **Learnings.** [`learnings.defaults.md`](../../learnings.defaults.md) holds what is already known about the repo. The agent adds its own findings to `learnings.md`, which is not committed.
- **`.agents/example/`.** In a project set up with the `empty` starter, the item example stays here as reference code. The agent copies its shape for a new feature.

## Why

An agent starts each session without memory of the last one. These files give it the rules at the start, so it does not guess. They stay short, so they fit in its context.

## How an agent is kept on track

The files tell the agent what to do. The gate checks that it did. This part of [`AGENTS.md`](../../AGENTS.md) says when work is done:

```markdown
## Before you say it is done

Run `tool/check.sh`. Work is done only when it ends with `All checks passed.` Report what it printed, and never report a check you did not run. The custom rules show only in `dart analyze` run from the repo root and in the gate; `flutter analyze` does not report them.
```

The doctor also checks the agent files themselves: `AGENTS.md` stays under its size limit, and each skill names only skills and paths that exist. Run it:

```bash
dart run flutter_agentify_core:doctor --only agent-files,skills
```

## Reference

- [Build with a coding agent](../tutorial/build-with-a-coding-agent.md): the prompt to paste, and what to check in the agent's report.
- [Quality gate](quality-gate.md): what the gate runs.
- [CLI and doctor](../../packages/flutter_agentify_core/doc/cli-and-doctor.md): the doctor's checks.
