# Qst Script Plugin API

This API is used by script plugins placed in `~/.config/qst/scripts/`.

Supported script styles:

- Executable scripts/binaries (run directly).
- Non-executable scripts with supported extensions (run via interpreter):
	- `.sh`, `.bash`, `.zsh`, `.fish`
	- `.py`
	- `.pl`
	- `.rb`
	- `.js`
	- `.lua`

The broader ecosystem is cataloged in `awesome-qst`:

- https://github.com/gitanelyon/awesome-qst

## Invocation model

- A script is invoked with the current query payload as arguments.
- Script stdout is parsed line-by-line by qst.
- Empty lines are ignored.

## Item output

- `Title|Value` → list row (`Title`) with payload (`Value`)
- `Title` → shorthand row where value defaults to title

## Host directives

Lines prefixed with `qst! ` are control directives:

- `qst! title <text>`
	- Sets list title.
- `qst! message <text>`
	- Sets the status/message line under the input.
- `qst! clear_message`
	- Clears the status/message line.
- `qst! action <Action>`
	- Sets default action for all list rows.
- `qst! item_action <Action>`
	- Sets action for only the next emitted row.
- `qst! default_item_action <Action>`
	- Sets action for all following rows unless overridden.
- `qst! item <title>|<value>|<Action>`
	- Emits an explicit row with optional per-item action.
- `qst! clear`
	- Clears all accumulated rows.
- `qst! single <query>|<result>`
	- Returns a single-result response instead of list mode.
- `qst! write <file>|<WriteAction>|<value>`
	- Mutates `~/.config/qst/storage/<plugin-name>/<file>`.
- `qst! read <file>`
	- Reads the entire file and emits each stored line as a row.
- `qst! read <file>|<ReadAction>`
	- Reads the file with the specified action and emits the result as a single row.
- `qst! delete <file>`
	- Deletes the stored file.

## Row metadata

Row metadata is appended to a directive or row using `@meta:<key>=<value>` tokens.

Example:

```bash
echo "qst! item  Back|Back|PopLastToken @meta:permanent=true @meta:nonselectable=false"
```

Rules:

- Metadata tokens are appended at the end of the row or directive payload.
- Multiple metadata tokens may be chained in the same row.
- If a literal `/@meta` is used at the start of a row, qst treats it as normal text. 

Supported row metadata keys:

- `display=<text>`
	- Overrides the visible label for the row.
- `fuzzy=<bool>`
	- Opts the row into host-side fuzzy filtering. When attached to a title or message directive, it enables fuzzy filtering for all rows in that script response.
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

### Main Actions

- `CopyToClipboardAndExit`
	- Copies value to clipboard and exits qst.
- `CopyToClipboard`
	- Copies value to clipboard and keeps qst open.
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
	- Executes value as a shell command and exits qst.
- `ExecuteAndRefresh`
	- Executes value as a shell command and keeps qst open.
- `ExecuteAndResetPrompt`
	- Executes value as a shell command, blocks until complete, and resets the search query back to its first token (e.g. `todo n example` becomes `todo `).
- `None`
	- No-op action, keeps qst open.

### Write Actions

- `pfront`
	- Push value to the front of the file.
- `pback`
	- Push value to the back of the file.
- `rmfront`
	- Remove a line from the front of the file.
- `rmback`
	- Remove a line from the back of the file.
- `purge`
	- Remove every stored line that exactly matches the provided value.

### Read Actions

- `fpeek`
	- Read a line from the front of the file without removing it.
- `bpeek`
	- Read a line from the back of the file without removing it.
- `all`
	- Read the entire file content.

Storage files are created automatically when a write directive targets a missing file.

## Example

```bash
#!/usr/bin/env bash
query="${1:-}"

echo "qst! title  Demo Script "

if [[ -z "$query" ]]; then
	echo "qst! action None"
	echo "  Type a command after the trigger|"
else
	echo "qst! action ExecuteAndExit"
	echo "  Run: $query|$query"
fi
```
