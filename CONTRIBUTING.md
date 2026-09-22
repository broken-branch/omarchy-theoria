# Contributing

This file is the whole contributor guide; the README is the user's document.

## What this is

An `omarchy-shell` bar widget for Theoria, a local research and
decision app. It is a thin client: it watches the discovery file `theoria open` writes
(`~/.local/share/theoria/server.json`), reads `GET /api/status` from the loopback URL and token in that file, and
runs `theoria open` and `omarchy-launch-webapp`. It is deliberately not a second Theoria GUI — the panel never
renders a report, a plan or a clarify question, it opens the app for those — and it never holds a key.

## Layout

- `manifest.json` — the plugin contract: id `io.github.broken-branch.theoria`, one `bar-widget` entry point.
- `Panel.qml` — the bar button and the panel. `RunCard.qml`, `RecentRuns.qml` — the two panel sections.
- `Engine.qml` — discovery, polling, starting the engine, opening the window.
- `spawn.js` — safe command, environment and curl-stdin construction for every spawned process.
- `status.js` — every formatting, ordering and URL decision, as plain functions (see the README's Development
  section). QML holds layout and process wiring only.
- `tests/status.test.js` — those functions against a status body.
- `check` — the gate; `.github/workflows/check.yml` runs it.

## The two constraints worth knowing

- The engine is started with `setsid -f` and its streams redirected first, or it dies with the QML object that
  spawned it when the shell reloads. The start is bounded: if no status answers within fifteen seconds the panel
  says so and Open works again.
- The status token reaches `curl` on stdin for both status and open calls. It never appears in process arguments.

## Standards

- The smallest change that works: no abstraction with one caller, no option nobody passes, no "for later" code.
- Names say what a thing is; comments say why, never what.
- A test exists to fail: before keeping one, name the one-line change to the code that turns it red.
- Test through the functions the QML calls, against a real status body. No mocks of the thing under test.
- `./check` passes before a pull request. A change a user sees updates the README in the same pull request.
- This repository is cloned onto every user's machine by `omarchy plugin add`: never commit credentials, personal
  data or run output.
