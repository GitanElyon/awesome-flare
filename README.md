# Awesome Flare

This repository contains a curated catalog of plugins for [flare](https://github.com/gitanelyon/flare), a terminal-first Linux application launcher built with Rust + Ratatui.

## What is here

- `scripts/`: executable plugin scripts (`*.sh`) used by Flare.
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
- `volume.sh`

## Install locally

```bash
mkdir -p ~/.config/flare/scripts
cp -r scripts/*.sh ~/.config/flare/scripts/
chmod +x ~/.config/flare/scripts/*.sh
```

Optional aliases can be defined in `~/.config/flare/scripts/alias.toml`.

If you use `.sh` keys, quote them in TOML:

```toml
"volume.sh" = "v!"
battery = ":"
"clipboard.sh" = "+"
```

Unquoted dotted keys also work, but they are interpreted as TOML dotted paths.

For protocol details, see [API.md](API.md).
