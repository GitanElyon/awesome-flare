<p align="center">
  <img src="assets/awesome-qst.svg" alt="qst Logo" width="577">
</p>


This repository contains a curated catalog of plugins for [qst](https://github.com/gitanelyon/qst), a terminal-first Linux application launcher built with Rust + Ratatui.

## What is here

- `scripts/`: plugin scripts used by qst (`*.sh`, `*.pl`, `*.py`, etc.).
- `API.md`: script protocol reference (`qst!` directives, actions, output format).
- `DOCS.md`: installation, aliases, and authoring guide.

## Included scripts

- `battery.sh`
- `bluetooth.sh`
- `brightness.sh`
- `calculator.sh`
- `clipboard.sh`
- `help.sh`
- `runner.sh`
- `sudo.sh`
- `symbols.sh`
- `symbols.pl`
- `volume.sh`

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
