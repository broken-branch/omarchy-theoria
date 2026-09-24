#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/home/.local/share/theoria/engine/node_modules/theoria" "$scratch/shell/engine"
cp Engine.qml status.js spawn.js "$scratch/shell/"
sed -i '/  property int refreshIntervalSec: 5/a\  readonly property bool testPollRunning: pollTimer.running\n  readonly property int testPollInterval: pollTimer.interval' "$scratch/shell/Engine.qml"
sed -i 's/launchProcess.command = command/launchProcess.command = ["\/usr\/bin\/true"]/' "$scratch/shell/Engine.qml"
cp engine/package.json "$scratch/shell/engine/package.json"
cp tests/engine-behavior.qml "$scratch/shell/shell.qml"
node -e 'const fs = require("fs"); const p = require("./engine/package.json"); fs.writeFileSync(process.argv[1], JSON.stringify({ version: p.dependencies.theoria }))' "$scratch/installed.json"

env -u XDG_CONFIG_HOME -u XDG_STATE_HOME HOME="$scratch/home" TEST_INSTALLED_PACKAGE="$scratch/installed.json" \
  QT_QPA_PLATFORM=offscreen timeout 10 quickshell --path "$scratch/shell/shell.qml" --no-color
