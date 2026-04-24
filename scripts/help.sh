#!/usr/bin/env bash
echo "qst! meta Script Commands, 1.0.0, GitanElyon, Lists available scripts and aliases."

SCRIPT_DIR="$HOME/.config/qst/scripts"
ALIAS_FILE="$HOME/.config/qst/alias.toml"

trim() {
	local value="$1"
	value="${value#"${value%%[![:space:]]*}"}"
	value="${value%"${value##*[![:space:]]}"}"
	printf '%s' "$value"
}

sanitize_text() {
	local value="$1"
	value="${value//$'\n'/ }"
	value="${value//|/¦}"
	printf '%s' "$value"
}

read_script_metadata() {
	local script_path="$1"
	local line name version author description

	line="$(sed -n 's/^echo "qst! meta //p' "$script_path" 2>/dev/null | head -n1)"
	[[ -n "$line" ]] || return 1
	line="${line%\"}"
	IFS=',' read -r name version author description <<< "$line"
	printf '%s\t%s\t%s\t%s' \
		"$(sanitize_text "$(trim "$name")")" \
		"$(sanitize_text "$(trim "$version")")" \
		"$(sanitize_text "$(trim "$author")")" \
		"$(sanitize_text "$(trim "$description")")"
}

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
	echo "  No script directory found at $SCRIPT_DIR @meta:center=true|"
	exit 0
fi

found=0
while IFS= read -r script; do
	base="$(basename "$script")"
	stem="${base%.sh}"
	[[ -z "$stem" ]] && continue
	found=1

	meta_name=""
	meta_version=""
	meta_author=""
	meta_description=""
	if metadata="$(read_script_metadata "$script")"; then
		IFS=$'\t' read -r meta_name meta_version meta_author meta_description <<< "$metadata"
	fi

	alias="${ALIASES[$stem]}"
	display="${meta_name:-$base}"
	[[ -n "$meta_version" ]] && display="${display} ${meta_version}"
	[[ -n "$alias" ]] && display="${display} [alias: ${alias}]"
	meta_terms="$(sanitize_text "$base $stem $alias $meta_name $meta_version $meta_author $meta_description")"
	if [[ -n "$alias" ]]; then
		echo "  ${base}|@meta:display=${display} @meta:meta=${meta_terms}"
	else
		echo "  ${base}|@meta:display=${display} @meta:meta=${meta_terms}"
	fi
done < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*.sh' -executable 2>/dev/null | sort)
if [[ "$found" == "0" ]]; then
	echo "  No executable scripts found in $SCRIPT_DIR @meta:center=true|"
fi
