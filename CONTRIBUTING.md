# Contributing to Awesome Qst

Contributions to the `awesome-qst` repo are welcome! This includes new scripts, bug fixes, documentation improvements, and more.

## How to contribute

Either open a pull request with your changes or open an issue to discuss new ideas or problems.

When contributing scripts, please ensure they follow the protocol outlined in `API.md` and include documentation in `DOCS.md` if necessary.

# Script Architecture

The `awesome-qst` script pack is designed to be modular and extensible. Each script is a separate module that can be easily added, removed, or updated without affecting the overall functionality of the pack. That being said, there are some guidelines to follow when creating new scripts:

Each script should be self-contained and smetahould not rely on other scripts unless absolutely necessary. If a script does depend on another script, it should clearly document this dependency in its documentation.

## Script Requirements

### Metadata

At the top each script should contain several lines outputing the script's name, version and author as its own `qst!` directive. A description is recommended but optional. This metadata is used by `help.sh` to display script information.

Example:
```bash
echo "qst! meta_name My Awesome script"
echo "qst! meta_version 1.0.0"
echo "qst! meta_author John Doe"
echo "qst! meta_description This script does awesome things!"
```
## Script Protocol

Scripts in `awesome-qst` communicate with the host application (qst) using a line-oriented protocol. Each line of output from a script is parsed by qst to determine how to update the UI, what actions to set, and how to respond to user input.

### Arguments

When a script is invoked, it receives the current query payload as its arguments. The script can use these arguments to generate dynamic output based on user input.

Arguments must be handled by the script itself and are not automatically parsed by qst. This allows for maximum flexibility in how scripts interpret and use the input data.

Unless there is a reason not to, scripts should accept single letter flags for common options (e.g. `h` for help, `v` for version, etc.) and should provide a `h` (`help`) option to display usage information.
