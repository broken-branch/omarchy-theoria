# Theoria for Omarchy

![The Theoria panel in the Omarchy bar](preview.png)

One bar icon and one panel for Theoria, a local research and decision
app: what the current run is doing and what it has spent, a box to start a run from a brief, the five most recent
runs, and a button that opens the app window.

## Requirements

- Omarchy with `omarchy-shell`, and `omarchy-launch-webapp` on `PATH` (both ship with Omarchy)
- `curl`
- Theoria itself, with `theoria` on `PATH`. The plugin reads its loopback server; it is not useful without it.
  Install it with `npm install -g theoria`, then run `theoria doctor`. Theoria runs on whichever AI you already
  have — a Claude, ChatGPT or Google subscription, an OpenAI-compatible endpoint such as OpenRouter, or a model
  running locally under Ollama or llama.cpp.

## Install as an Omarchy plugin

```sh
omarchy plugin add https://github.com/broken-branch/omarchy-theoria.git
omarchy plugin enable io.github.broken-branch.theoria
```

A plugin lands disabled so you can read its code before enabling it. Put the widget where you want it with
`omarchy bar move io.github.broken-branch.theoria`.

To remove it:

```sh
omarchy plugin disable io.github.broken-branch.theoria
omarchy plugin remove io.github.broken-branch.theoria
```

Disabling takes the icon off the bar; removing deletes the plugin folder. Neither touches Theoria, its settings or
its runs.

## Panel

The bar always shows the Theoria mark. During a run it adds the stage and the tokens spent — "Researching · 118k" —
or **Needs you** when the run is waiting for an answer. Click the icon for the panel, right-click to open the app.

The panel shows the current run's brief, stage, budget meter, estimated spend and elapsed time; a brief box that
opens Theoria's New run screen with your text filled in; the five most recent runs, each opening its own screen;
and **Open Theoria**. When no server is running, the panel says so and Open starts one.

Theoria runs one thing at a time, so the brief box is disabled while a run is going.

## Settings

`refreshIntervalSec` (default 5) is how often the panel asks the running engine for its status. It polls once a
minute while the engine is idle, and not at all when no engine is running.

## What it reads and runs

It watches `~/.local/share/theoria/server.json`, which `theoria open` writes, and reads `GET /api/status` from the
loopback address and token in that file. It runs three commands: `curl` for the status, `theoria open` to start the
engine when none is running, and `omarchy-launch-webapp` to open the window. Each command is resolved to an absolute
path at startup and run with a minimal environment. It holds no key, stores nothing and sends nothing off the
machine.

## Development

`./check` is the whole gate: the required files exist, the manifest is valid, `qmllint` accepts every QML file when
Qt's tools are installed, and the unit tests of `status.js` pass. `status.js` holds every formatting and URL
decision so it can be proven without Qt; QML holds layout and process wiring only. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
