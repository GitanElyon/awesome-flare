# Qst Plugin Docs (Script Pack)

This folder is the script-plugin side of qst (the `awesome-qst` plugin set).

## Install scripts

```bash
mkdir -p ~/.config/qst/scripts
cp -r scripts/* ~/.config/qst/scripts/
chmod +x ~/.config/qst/scripts/*
```

Restart qst after adding scripts.

## Aliases

`help.sh` reads aliases from:

- `~/.config/qst/alias.toml`

Example:

```toml
[scripts]
"volume.sh" = "v!"
battery = ":"
"clipboard.sh" = "+"
"symbols.pl" = "sym!"

[apps]
"btop++" = "alacritty -e btop"
```

Notes:

- Keys may include or omit script extensions (`.sh`, `.pl`, etc.).
- Quoted keys are recommended when keys include dots.
- Unquoted dotted keys are treated as TOML dotted paths but are still supported by qst alias parsing.

## Script contract

- Input: script arguments from current query.
- Output: line-oriented protocol parsed by qst.
- Control: use `qst!` directives for title, actions, item overrides, and single-result mode.

## Script metadata

Scripts may start with a metadata line such as:

```bash
echo "qst! meta Script Name, 1.0.0, Author Name, Short description"
```

The fields are, in order:

- `name`
- `version`
- `author`
- `description`

The helper scripts read that header to show names, versions, authors, and descriptions in their own views, and qst also recognizes `qst! meta name`, `qst! meta version`, `qst! meta author`, and `qst! meta description` as field selectors after the header has been declared.

Full protocol reference: [API.md](API.md).