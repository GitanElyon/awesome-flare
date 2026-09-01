# Qst Script Docs

This directory contains the script-pack for qst, including the bundled scripts, authoring notes, and protocol reference.

## Install scripts

```bash
mkdir -p ~/.config/qst/scripts
cp -r scripts/* ~/.config/qst/scripts/
chmod +x ~/.config/qst/scripts/*
```

Or use Qst's built-in `loader.sh` helper to browse and install scripts from the [awesome-qst](https://github.com/GitanElyon/awesome-qst) repository.

Restart qst after adding or updating scripts.

## Script loader

The `loader.sh` helper browses the [awesome-qst](https://github.com/GitanElyon/awesome-qst) catalog. It fetches the repository's `catalog.tsv`, which lists every script with its name, version, author, and description. The catalog is cached locally for 24 hours and falls back to the cached copy when the network is unavailable.

Installed scripts are highlighted in the list, and scripts whose installed version is older than the catalog version are flagged as out of date. Those scripts can be updated directly from the loader (`loader u <script>`), which replaces the local copy with the newest catalog version.

## Aliases

Aliases are optional triggers for scripts. They are defined in `~/.config/qst/alias.toml` and read by `help.sh` and `loader.sh`. Aliases can be used to invoke scripts with a shorter or more memorable trigger.

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

Full protocol reference: [qst Script API](https://github.com/GitanElyon/qst/blob/main/API.md). For advanced authoring examples, see [API.md](API.md).