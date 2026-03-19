# Flare Plugin Docs (Script Pack)

This folder is the script-plugin side of Flare (the `awesome-flare` plugin set).

## Install scripts

```bash
mkdir -p ~/.config/flare/scripts
cp -r scripts/*.sh ~/.config/flare/scripts/
chmod +x ~/.config/flare/scripts/*.sh
```

Restart Flare after adding scripts.

## Aliases

`help.sh` reads aliases from:

- `~/.config/flare/scripts/Alias.toml`

Example:

```toml
volume.sh = "v!"
battery.sh = ":"
clipboard.sh = "+"
```

## Script contract

- Input: script arguments from current query.
- Output: line-oriented protocol parsed by Flare.
- Control: use `f!` directives for title, actions, item overrides, and single-result mode.

Full protocol reference: [API.md](API.md).

## Publishing

Share new scripts and plugin packs through:

- https://github.com/gitanelyon/awesome-flare
