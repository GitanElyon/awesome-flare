# Awesome Flare (Plugins)

This directory is the plugin pack for Flare and maps to the `awesome-flare` ecosystem.

The canonical plugin catalog and community list lives at:

- https://github.com/gitanelyon/awesome-flare

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

Optional aliases can be defined in `~/.config/flare/scripts/Alias.toml`.

For protocol details, see [API.md](API.md).
