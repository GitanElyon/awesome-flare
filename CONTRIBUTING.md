# Contributing to Awesome Qst

Contributions to the `awesome-qst` repo are welcome! This includes new scripts, bug fixes, documentation improvements, and more.

## How to contribute

Either open a pull request with your changes or open an issue to discuss new ideas or problems.

When contributing scripts, please ensure they follow the protocol outlined in `API.md` and include documentation in `DOCS.md` if necessary.

## Script standards

Every script added to this pack should meet the following baseline standards:

- Be self-contained and focused on one task.
- Start with a metadata line in the format described in `API.md` so `help.sh` and `loader.sh` can identify the script.
- Accept the current query payload through script arguments and handle empty input cleanly.
- Support a `h` or `--help` style help path, and a `v` or `--version` path when it makes sense for the script.
- Emit only qst-compatible line-oriented output on stdout; keep stray logging, debugging, and errors off the normal output stream.
- Use `qst!` directives consistently for titles, messages, actions, item overrides, and storage operations.
- Document any non-obvious behavior, required dependencies, or external state in `DOCS.md`.
- Preserve backward compatibility when possible, especially for metadata fields, aliases, and action names.
- Prefer portable shell or interpreter features that work with the supported script styles listed in `API.md`.
- Fail clearly when required dependencies are missing or when the script cannot complete its task.
- For Bash scripts, enable `set -euo pipefail` by default and make any intentional empty or missing-value cases explicit in the code.
- Run `bash -n` on edited shell scripts before opening a pull request.

Scripts that manage persistent state should also follow these rules:

- Use the qst storage directives instead of inventing a private storage format when qst already provides the needed behavior.
- Keep stored values stable and predictable so helper scripts and future changes can read them safely.
- Avoid destructive writes unless the user explicitly requested a destructive action.

# Script Architecture

The `awesome-qst` script pack is designed to be modular and extensible. Each script is a separate module that can be easily added, removed, or updated without affecting the overall functionality of the pack. That being said, there are some guidelines to follow when creating new scripts:

Each script should be self-contained and should not rely on other scripts unless absolutely necessary. If a script does depend on another script, it should clearly document this dependency in its documentation.

## Script Requirements

### Metadata

At the top each script should contain a metadata line that declares the script's name, version, author, and optional description. This metadata is used by `help.sh` and `loader.sh` to display script information.

Example:
```bash
echo "qst! meta My Script, 1.0.0, Your Name, A brief description of what the script does"
```

Scripts can also emit `qst! meta name`, `qst! meta version`, `qst! meta author`, or `qst! meta description` after the header if they need one field for their own UI.
## Script Protocol

Scripts in `awesome-qst` communicate with the host application (qst) using a line-oriented protocol. Each line of output from a script is parsed by qst to determine how to update the UI, what actions to set, and how to respond to user input.

### Arguments

When a script is invoked, it receives the current query payload as its arguments. The script can use these arguments to generate dynamic output based on user input.

Arguments must be handled by the script itself and are not automatically parsed by qst. This allows for maximum flexibility in how scripts interpret and use the input data.

Unless there is a reason not to, scripts should accept single letter flags for common options (e.g. `h` for help, `v` for version, etc.) and should provide a `h` (`help`) option to display usage information.
