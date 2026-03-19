#!/usr/bin/env bash

SCRIPT_DIR="$HOME/.config/flare/scripts"
ALIAS_FILE="$SCRIPT_DIR/Alias.toml"

echo "f! title  Script Commands "
echo "f! action None"

declare -A ALIASES
if [[ -f "$ALIAS_FILE" ]]; then
	while IFS= read -r line; do
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ "$line" != *"="* ]] && continue

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