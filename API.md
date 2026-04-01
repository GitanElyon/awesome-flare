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
- `f! message <text>`
	- Sets the status/message line under the input.
- `f! clear_message`
	- Clears the status/message line.
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

## Row metadata

Row metadata is appended to a directive or row using `@meta:<key>=<value>` tokens.

Example:

```bash
echo "f! item  Back|Back|PopLastToken @meta:permanent=true @meta:nonselectable=false"
```

Rules:

- Metadata tokens are appended at the end of the row or directive payload.
- Multiple metadata tokens may be chained in the same row.
- If a literal `/@meta` is used at the start of a row, Flare treats it as normal text. 

Supported row metadata keys:

- `display=<text>`
	- Overrides the visible label for the row.
- `meta=<terms>`
	- Adds hidden search terms. Separate multiple terms with commas.
- `nonselectable=<bool>`
	- Skips the row during selection movement.
- `permanent=<bool>`
	- Keeps the row available for UI flows that preserve permanent rows.
- `active=<bool>`
	- Marks the row as active in the UI.
- `urgent=<bool>`
	- Marks the row as urgent in the UI.

## Supported actions

- `CopyToClipboardAndExit`
- `CopyToClipboard`
- `SetStatusMessage`
- `ClearStatusMessage`
- `SetSearchQuery`
- `AppendToQuery`
- `PrependToQuery`
- `ReplaceLastToken`
- `PopLastToken`
- `PopLastChar`
- `ClearQuery`
- `RefreshResults`
- `ExecuteAndExit`
- `ExecuteAndRefresh`
- `None`

### Action semantics

- `CopyToClipboardAndExit`
	- Copies value to clipboard and exits Flare.
- `CopyToClipboard`
	- Copies value to clipboard and keeps Flare open.
- `SetStatusMessage`
	- Sets the status/message line to value.
- `ClearStatusMessage`
	- Clears the status/message line.
- `SetSearchQuery`
	- Replaces the current query with value.
- `AppendToQuery`
	- Appends value to the current query.
- `PrependToQuery`
	- Inserts value at the beginning of the current query.
- `ReplaceLastToken`
	- Replaces the trailing whitespace-delimited token with value.
- `PopLastToken`
	- Removes the trailing whitespace-delimited token from the current query.
- `PopLastChar`
	- Removes the last character from the current query.
- `ClearQuery`
	- Clears the entire query.
- `RefreshResults`
	- Re-runs filtering/script resolution without changing query text.
- `ExecuteAndExit`
	- Executes value as a shell command and exits Flare.
- `ExecuteAndRefresh`
	- Executes value as a shell command and keeps Flare open.
- `None`
	- No-op action, keeps Flare open.

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
