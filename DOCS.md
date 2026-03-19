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

- `~/.config/flare/scripts/alias.toml`

Example:

```toml
"volume.sh" = "v!"
battery = ":"
"clipboard.sh" = "+"
```

Notes:

- Keys may include or omit `.sh`.
- Quoted keys are recommended when keys include dots.
- Unquoted dotted keys are treated as TOML dotted paths but are still supported by Flare alias parsing.

## Script contract

- Input: script arguments from current query.
- Output: line-oriented protocol parsed by Flare.
- Control: use `f!` directives for title, actions, item overrides, and single-result mode.

Full protocol reference: [API.md](API.md).