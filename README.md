# Theoria for Omarchy

![Theoria research app](preview.png)

## What Theoria is

Theoria answers a question or makes a decision for you, and shows its sources. You write a brief, such as "Should a
small team adopt pnpm workspaces?" or "What changed in Wayland screen sharing this year?" You answer up to four
clarifying questions and confirm a plan and a token budget. Then it works on its own. It splits the brief into
sub-questions, researches each one on the web, and writes the report. Before you see it, a critic checks every claim
against its sources.

You get back one of two things:

- a **decision record**: a recommendation with its confidence, the reasoning, the risks, and what would change the
  answer; or
- a **research report**: what is known, with a citation on every claim, and open questions marked as open.

You read it in a page on your own machine. You can export it as Markdown, TXT or PDF for a person, or as a JSON bundle
for another AI.

You pick one of four budget sizes before anything runs:

- **Quick** (300k tokens, a short answer) for a narrow question
- **Standard** (1.2M) for most questions
- **Deep** (2.5M) or **Exhaustive** (5M) when the question has several sides or being wrong is expensive

It runs on AI you already have: a Claude, ChatGPT or Google subscription, an OpenAI-compatible endpoint such as
OpenRouter, or a local model under Ollama or llama.cpp. Each stage can use a different one. Runs and settings stay on
your machine. The only traffic is to the models you chose, plus the searches and web pages a run reads.

Theoria is a separate, MIT-licensed app ([source](https://github.com/broken-branch/theoria) ·
[npm](https://www.npmjs.com/package/theoria)). This plugin is its remote control in the Omarchy bar and contains none
of Theoria's code.

## Set up

1. **Add the plugin.** Omarchy needs `omarchy-shell` and `omarchy-launch-webapp`.

   ```sh
   omarchy plugin add https://github.com/broken-branch/omarchy-theoria.git
   omarchy plugin enable io.github.broken-branch.theoria
   ```

   A plugin lands disabled so you can read its code before enabling it. Put the widget where you want it with
   `omarchy bar move io.github.broken-branch.theoria`.

2. **Install Theoria.** The plugin runs one exact, reviewed version of Theoria, installed from this plugin's lockfile
   into your home directory. It needs Arch's `nodejs` (Node 24 or newer), `npm` and `curl`, and takes about 290 MB.

   ```sh
   mkdir -p ~/.local/share/theoria/engine
   cp ~/.config/omarchy/plugins/io.github.broken-branch.theoria/engine/package.json ~/.config/omarchy/plugins/io.github.broken-branch.theoria/engine/package-lock.json ~/.local/share/theoria/engine/
   npm ci --prefix ~/.local/share/theoria/engine --ignore-scripts
   ~/.local/share/theoria/engine/node_modules/.bin/theoria doctor
   ```

   `theoria doctor` prints `ok:` or `fix:` for each requirement.

3. **Choose your AI.** Open Theoria and pick your vendor and model under **Settings**. The default is Claude through
   Claude Code (`claude auth login`).

Notes:

- A shell `theoria` command is optional: you can symlink it to
  `~/.local/share/theoria/engine/node_modules/.bin/theoria`. The panel always starts the private engine and never runs
  a `theoria` found on your shell path. Keep `node_modules` outside the plugin folder; Omarchy plugin validation
  refuses symlinks there.
- An engine started by the panel has `PATH=/usr/local/bin:/usr/bin:/bin`. The `codex` and `gemini` providers need their
  CLIs in one of those directories; otherwise start Theoria from a shell.

To remove it:

```sh
omarchy plugin disable io.github.broken-branch.theoria
omarchy plugin remove io.github.broken-branch.theoria
```

Disabling takes the icon off the bar; removing deletes the plugin folder. Neither touches Theoria, its settings or
its runs.

## Panel

![The Theoria panel in the Omarchy bar](assets/panel.png)

The bar always shows the Theoria mark. During a run it adds the stage and the tokens spent — "Researching · 118k" —
or **Needs you** when the run is waiting for an answer. Click the icon for the panel, right-click to open the app.

The panel shows the current run's brief, stage, budget meter, estimated spend and elapsed time; a brief box that
opens Theoria's New run screen with your text filled in; the five most recent runs, each opening its own screen;
and **Open Theoria**. When no server is running, the panel says so and Open starts one. If the pinned
Theoria version is missing or another version is installed, the panel shows setup commands for this plugin's
location, a **Copy** button, and a link to the setup steps. It returns to the normal view after the pinned
version is installed.

Theoria runs one thing at a time, so the brief box is disabled while a run is going.

## Settings

`refreshIntervalSec` (default 5) is how often the panel asks the running engine for its status. It polls once a
minute while the engine is idle, and not at all when no engine is running.

## What it reads and runs

It watches `~/.local/share/theoria/server.json`, which the engine writes, and reads `GET /api/status` from the
loopback address and token in that file. To open the app, it asks the engine for a one-time link (`POST /api/open`)
and passes that link to `omarchy-launch-webapp`; the token reaches `curl` on stdin, not in process arguments.
**Setup steps** opens this plugin's [GitHub README](https://github.com/broken-branch/omarchy-theoria#readme)
through the same launcher. To start the engine,
it reads `~/.local/share/theoria/engine/node_modules/theoria/package.json` and runs
`~/.local/share/theoria/engine/node_modules/theoria/dist/cli/main.js` through `node` only when the package matches the
Theoria version pinned in `engine/package.json`. The engine
is detached from the panel. `node`, `curl` and the webapp launcher are resolved from
`/usr/local/bin:/usr/bin:/bin` and run with a minimal environment. It holds no key, stores nothing and sends
its status and open API requests only to the loopback engine. Opening Setup steps visits GitHub in the browser.

## Development

`./check` is the whole gate: the required files exist, the manifest is valid, `qmllint` accepts every QML file when
Qt's tools are installed, and the unit tests of `status.js` pass. `status.js` holds every formatting and URL
decision so it can be proven without Qt; QML holds layout and process wiring only. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
