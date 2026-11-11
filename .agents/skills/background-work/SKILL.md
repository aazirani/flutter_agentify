---
name: background-work
description: What the operating systems allow when the app is not in front, and how long-running work should report progress. Use when a feature needs to keep working after the screen closes, run on a schedule, show progress or send notifications.
---

# Background work

Don't load this for slow code that freezes the screen; see `performance`. For platform permissions, see `permissions-and-platform`.

## Rule

Long work shows its progress in the UI and can be stopped. No hidden loop, timer or isolate keeps working on its own. Anything that needs a new dependency (background execution, notifications, scheduling) needs the person's approval first: say what it is for and what it costs, and wait. No automated check exists for this rule; the app today has no background work (`lib/main.dart` only starts the app), except the in-app model download in projects set up with `--model both` or `on-device`, which shows progress and can be cancelled.

## Why

Mobile systems stop or kill background apps, so work that only runs "in the background" silently does not finish. Hidden work also cannot be approved, observed or cancelled by the person, which breaks the idea that the UI and assistant share one visible set of actions.

## How

What each OS allows, in short:

- **iOS:** almost nothing once the app is suspended; short grace time, then system-scheduled refreshes at the system's discretion. Exact timing is not available.
- **Android:** background work must be scheduled through the system (and long work shown with a foreground-service notification); the system limits it further when battery is low.
- **Web:** nothing runs when the tab is closed; throttled when hidden.
- **macOS, Windows, Linux:** the app keeps running while it is open, even without focus; nothing runs after it quits unless the person sets up a login item or service.

So design for "work happens while the app is open", and make the rest resumable:

1. Make the work an action (`actions`) that does one bounded piece and returns. A long job is many small calls, each recorded.
2. Keep job state in the database (`storing-data`), not in memory, so the app can pick up after being closed.
3. Show progress in a screen the person can open: a count, a status line, a stop button. Put the same facts in the screen summary (`app-context`) so the assistant can report them.
4. Use a notification only to tell the person something finished or needs them, and only after a permission request that the person can refuse.
5. If a real background mechanism is unavoidable, ask the person for the dependency first, then add its platform settings (`permissions-and-platform`).

## Anti-patterns

- A `Timer.periodic` or endless `while` loop started at launch.
- Assuming a task will run on a schedule on iOS.
- Adding a plugin because "it is only one package".
- Progress kept only in a variable, lost when the app closes.
- An action that runs for minutes with no way to cancel.

## Verification

- No automated check. Review by hand: can the person see it, stop it, and find it again after a restart?
- Test the job's steps as actions (`testing`) and run the app on a real device in the background for the platforms you support.

## Related skills
- `actions` — one bounded step per call
- `storing-data` — job state that survives restarts
- `reliable-mutations` — safe retries of a step
- `permissions-and-platform` — notification and background settings
