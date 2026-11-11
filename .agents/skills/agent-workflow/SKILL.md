---
name: agent-workflow
description: How an agent works in Flutter Agentify, covering when to go ahead, when to stop and ask, how to record assumptions, how to leave a handoff note and how to end with a status line and change summary. Use when starting a task, hitting an unclear requirement, pausing before finishing or reporting results.
---

# Agent workflow

Don't load this for which files you may edit; see `edit-boundaries`.

## Rule

Go ahead when the task is clear and the change is reversible. Stop and ask when it is not. Write down every assumption you make. End with a status line and a short change summary that says only what you ran.

## Why

A person reading your result cannot see what you guessed. Asking one precise question early costs less than undoing a wrong feature. A report that claims a check you did not run is worse than no report. `AGENTS.md` says work is done only when `tool/check.sh` ends with `All checks passed.`

## How

**Go ahead** when the request names the behaviour, the change stays inside the layers in `AGENTS.md`, and it is easy to undo. Pick the repo's own pattern and keep going.

**Stop and ask** when:
- two readings of the request would produce different features or different data;
- it needs a new dependency, platform configuration, CI change or a change to `analysis_options.yaml` (see `edit-boundaries`);
- it deletes or rewrites the person's data, or changes a database table beyond adding tables or nullable columns;
- the right action, route or screen does not exist and the scope is large;
- a check fails and fixing it would mean raising a baseline or adding an ignore.

Ask once, with the options and your pick: "A or B? I will do A unless you say otherwise." Then continue with what does not depend on the answer.

**Assumptions.** When you proceed on a guess, put it in your notes as one line each: "Assumed: items keep their order by creation time." Repeat them in the final summary.

**Handoff note.** If you stop before finishing, leave a note another agent can continue from, in your reply (not a new file): the goal; what is done, with file paths; what is left; the exact commands to resume (for example `tool/check.sh`); what failed and the message; and open questions.

**Ending.** Finish with:
1. A status line: `Done`, `Blocked on <question>` or `Partly done: <what is left>`.
2. What `tool/check.sh` printed, or which steps you ran and which you did not.
3. A change summary: each file or area changed, one line each, grouped by layer, plus any new action, route or translation key.
4. The assumptions.

If you learned something the next session should know, follow `capture-learnings`.

## Anti-patterns

- Starting a large feature while the request is still ambiguous.
- Asking several questions at once, or one you could answer by reading the code or the docs (see `read-the-docs`).
- Saying "tests pass" after running only one test file.
- Burying an assumption in the code instead of the summary.
- A handoff note that says "mostly done" with no paths or commands.
- Hiding a failing gate step instead of reporting it.

## Verification

No automated check covers this behaviour. The gate (`tool/check.sh`) verifies the code only; the status line and summary are yours to get right. A reviewer can compare your summary with the files changed and with the gate's output.

## Related skills

- `edit-boundaries` — what needs a question first.
- `verify` — running the gate and quoting its result.
- `capture-learnings` — saving a correction or preference.
- `read-the-docs` — answers you can find before asking.
- `adding-a-feature` — the steps for a typical feature.
