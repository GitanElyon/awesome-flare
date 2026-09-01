# Overview

This directory contains the random one-off scripts and other assets used to build and maintain qst and awesome-qst.

# Contents

## Titlegen

`titlegen.py` is the python script I used to generate the ascii text logo used at the top of the README in both the [qst](https://github.com/gitanelyon/qst) and the [awesome-qst](https://github.com/gitanelyon/awesome-qst) repos.

The original title text was generated using [patorjk's Text to ASCII Art Generator](https://patorjk.com/software/taag), and I used the script to convert the output into an svg that I could include in the codebase. The script also includes some basic functionality for customizing the input text and font, but it was primarily a one-off utility for this specific purpose.

## Catalog Generator

`generate_catalog.sh` scans every script in `scripts/`, reads its `qst! meta` header, and writes the `catalog.tsv` file at the repository root. The `loader.sh` script in qst uses this catalog to browse scripts and to compare installed versions against the catalog for updates.

Usage:

```bash
misc/generate_catalog.sh
```

The catalog is a tab-separated file with one row per script:

```
file	name	version	author	description
```

Run the generator and commit the regenerated `catalog.tsv` whenever you add, remove, or update a script.