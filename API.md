# Flare Script Plugin API

This API is used by script plugins placed in `~/.config/flare/scripts/`.

Supported script styles:

- Executable scripts/binaries (run directly).
- Non-executable scripts with supported extensions (run via interpreter):
	- `.sh`, `.bash`, `.zsh`, `.fish`
	- `.py`
	- `.pl`
	- `.rb`
	- `.js`
	- `.lua`

The broader ecosystem is cataloged in `awesome-flare`:

- https://github.com/gitanelyon/awesome-flare

## Invocation model

- A script is invoked with the current query payload as arguments.
- Script stdout is parsed line-by-line by Flare.
- Empty lines are ignored.

## Item output

- `Title|Value` → list row (`Title`) with payload (`Value`)
- `Title` → shorthand row where value defaults to title

## Host directives

Lines prefixed with `f! ` are control directives:

- `f! title <text>`
	- Sets list title.
- `f! action <Action>`
	- Sets default action for all list rows.
- `f! item_action <Action>`
	- Sets action for only the next emitted row.
- `f! default_item_action <Action>`
	- Sets action for all following rows unless overridden.
- `f! item <title>|<value>|<Action>`
	- Emits an explicit row with optional per-item action.
- `f! clear`
	- Clears all accumulated rows.
- `f! single <query>|<result>`
	- Returns a single-result response instead of list mode.

## Supported actions

- `CopyToClipboardAndExit`
- `SetSearchQuery`
- `AppendToQuery`
- `ClearQuery`
- `ExecuteAndExit`
- `ExecuteAndRefresh`
- `None`

## Example

```bash
#!/usr/bin/env bash
query="${1:-}"

echo "f! title  Demo Script "

if [[ -z "$query" ]]; then
	echo "f! action None"
	echo "  Type a command after the trigger|"
else
	echo "f! action ExecuteAndExit"
	echo "  Run: $query|$query"
fi
```
