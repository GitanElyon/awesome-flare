#!/usr/bin/env bash

SCRIPT_DIR="$HOME/.config/qst/scripts"
ALIAS_FILE="$HOME/.config/qst/alias.toml"

echo "qst! title  Script Commands "
echo "qst! action None"

declare -A ALIASES
if [[ -f "$ALIAS_FILE" ]]; then
	has_scripts_section=$(grep -Fc "[scripts]" "$ALIAS_FILE")
	in_scripts_section=0

	while IFS= read -r line; do
		[[ "$line" =~ ^[[:space:]]*# ]] && continue

		if [[ "$line" =~ ^[[:space:]]*\[(.*)\] ]]; then
			section="${BASH_REMATCH[1]}"
			if [[ "$section" == "scripts" ]]; then
				in_scripts_section=1
			else
				in_scripts_section=0
			fi
			continue
		fi

		[[ "$line" != *"="* ]] && continue

		if [[ "$has_scripts_section" -gt 0 && "$in_scripts_section" == 0 ]]; then
			continue
		fi

		key="${line%%=*}"
		value="${line#*=}"

		key="$(echo "$key" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
		value="$(echo "$value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g; s/^"(.*)"$/\1/')"
		key="${key%.sh}"
		[[ -z "$key" || -z "$value" ]] && continue
		ALIASES["$key"]="$value"
	done < "$ALIAS_FILE"
fi

if [[ ! -d "$SCRIPT_DIR" ]]; then
	echo "  No script directory found at $SCRIPT_DIR|"
	exit 0
fi

found=0
while IFS= read -r script; do
	base="$(basename "$script")"
	stem="${base%.sh}"
	[[ -z "$stem" ]] && continue
	found=1

	alias="${ALIASES[$stem]}"
	if [[ -n "$alias" ]]; then
		echo "  ${base}  -> alias: ${alias}|"
	else
		echo "  ${base}|"
	fi
done < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*.sh' -executable 2>/dev/null | sort)
if [[ "$found" == "0" ]]; then
	echo "  No executable scripts found in $SCRIPT_DIR|"
fi
