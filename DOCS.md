# Qst Script Docs

This directory contains the script-pack for qst, including the bundled scripts, authoring notes, and protocol reference.

## Install scripts

```bash
mkdir -p ~/.config/qst/scripts
cp -r scripts/* ~/.config/qst/scripts/
chmod +x ~/.config/qst/scripts/*
```

Restart qst after adding or updating scripts.

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

- Keys may include or omit script extensions such as `.sh` or `.pl`.
- Quote keys that contain dots or other TOML-sensitive characters.
- Unquoted dotted keys are treated as TOML dotted paths, and qst still resolves them correctly.

## Script contract

- Input: scripts receive the current query payload as command-line arguments.
- Output: scripts must emit qst's line-oriented protocol on standard output.
- Control: use `qst!` directives for titles, actions, item overrides, and single-result responses.

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

The helper scripts read that header to display script names, versions, authors, and descriptions. After the header has been emitted, qst also recognizes `qst! meta name`, `qst! meta version`, `qst! meta author`, and `qst! meta description` as field selectors.

Full protocol reference: [API.md](API.md).