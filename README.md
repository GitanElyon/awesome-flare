<p align="center">
  <img src="assets/awesome-qst.svg" alt="qst Logo" width="577">
</p>


This repository contains a curated catalog of plugins for [qst](https://github.com/gitanelyon/qst), a terminal-first Linux application launcher built with Rust + Ratatui.

## What is here

- `scripts/`: plugin scripts used by qst (`*.sh`, `*.pl`, `*.py`, etc.).
- `API.md`: script protocol reference (`qst!` directives, actions, output format).
- `DOCS.md`: installation, aliases, and authoring guide.

Scripts can also declare a metadata header with `qst! meta name,version,author,description`. qst recognizes the same header at runtime, and `help.sh` and `loader.sh` can surface richer details from it.

## Included scripts

- `battery.sh`
  - Gives battery status and controls.
- `bluetooth.sh`
  - Lists paired Bluetooth devices and controls.
- `brightness.sh`
  - Shows and adjusts screen brightness.
- `clock.sh`
  - Displays the current time and date. Has timers and stopwatch features.
- `calculator.sh`
  - A simple calculator that evaluates expressions.
- `clipboard.sh`
  - Shows clipboard history, select item to add to clipboard.
- `help.sh`
  - Shows available plugins, their aliases and metadata.
- `loader.sh`
  - Quick script to add, remove, and manage other plugins.
- `runner.sh`
  - Allows running standard shell commands
- `system.sh`
  - Shows system information and controls.
- `todo.sh`
  - A basic todo list tool.
- `sudo.sh`
  - A quick way to run commands with sudo.
- `symbols.sh`
  - A dyanamically loaded list of all nerd-font symbols, for easy copying.
- `volume.sh`
  - Shows and adjusts system volume.

## Install locally

```bash
mkdir -p ~/.config/qst/scripts
cp -r scripts/* ~/.config/qst/scripts/
chmod +x ~/.config/qst/scripts/*
```

Optional aliases can be defined in `~/.config/qst/alias.toml`.

If you use extension-based keys (`.sh`, `.pl`, etc.), quote them in TOML:

```toml
[scripts]
"volume.sh" = "v!"
battery = ":"
"clipboard.sh" = "+"
"symbols.pl" = "sym!"

[apps]
# You can also set app aliases!
"btop++" = "alacritty -e btop"
```

Unquoted dotted keys also work, but they are interpreted as TOML dotted paths.

For protocol details, see [API.md](API.md).
