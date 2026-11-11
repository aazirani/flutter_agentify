---
name: capture-learnings
description: What to save to learnings.md, in what format, and how it differs from learnings.defaults.md. Use when the person corrects you, states a preference, or you find something surprising about this repository.
---

# Capture learnings

Don't load this for looking things up before work; see `read-the-docs`.

## Rule

At the start of a session read `learnings.defaults.md` and, if it exists, `learnings.md`. When something worth keeping happens, append one line to `learnings.md`.

## Why

A correction should only be needed once. The next session starts with no memory of this one, so a one-line note is the only thing that carries over.

## How

**Two files.**
- `learnings.defaults.md` is committed and ships with the template: facts true for every checkout (for example, generated files are not committed, and the custom lint rules show only in `dart analyze` from the repo root). Do not edit it for a personal preference; change it only when the task is to improve the template, and ask first.
- `learnings.md` is yours, listed in `.gitignore` and not committed. Create it if it does not exist.

**Worth saving:**
- a correction the person gave you ("use `watch…` names for streams");
- a stated preference ("keep summaries to five lines");
- a surprising fact about this repo that cost you time (a command that behaves differently than expected, a test helper quirk).

**Not worth saving:** anything already in `learnings.defaults.md`, `AGENTS.md` or a skill; one-time details of the current task; anything secret. Never write a key, token or personal data.

**Format.** One line, starting with the date, plain words, the fact and when it applies:

```
2026-11-09 — The person wants new translation keys added to both language files in the same change.
```

Append, do not rewrite old lines. If a new line contradicts an older one, add the newer line and say it replaces the older.

## Anti-patterns

- Saving a paragraph, or a diff.
- Saving a guess as a fact. Check it first.
- Writing a preference into `learnings.defaults.md`.
- Saving the same fact again under different words.
- Skipping the read at the start of a session.

## Verification

No automated check exists for this. `learnings.md` is ignored by git, so nothing will show it in review; check by reading the file back. The doctor's `agent-files` check covers `AGENTS.md`, which tells agents to do the reading and the appending.

## Related skills

- `agent-workflow` — mention new learnings in your final summary.
- `read-the-docs` — look it up first; save only what the docs missed.
