# Awesome Flare

This repository contains a curated catalog of plugins for [flare](https://github.com/gitanelyon/flare), a terminal-first Linux application launcher built with Rust + Ratatui.

## What is here

- `scripts/`: plugin scripts used by Flare (`*.sh`, `*.pl`, `*.py`, etc.).
- `API.md`: script protocol reference (`f!` directives, actions, output format).
- `DOCS.md`: installation, aliases, and authoring guide.

## Included scripts

- `battery.sh`
- `bluetooth.sh`
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
mkdir -p ~/.config/flare/scripts
cp -r scripts/* ~/.config/flare/scripts/
chmod +x ~/.config/flare/scripts/*
```

Optional aliases can be defined in `~/.config/flare/alias.toml`.

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
