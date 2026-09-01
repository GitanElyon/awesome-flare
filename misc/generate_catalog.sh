#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/scripts"
OUT="${REPO_ROOT}/catalog.tsv"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

supported_ext() {
	local file="$1"
	case "$file" in
		*.sh|*.bash|*.zsh|*.fish|*.py|*.pl|*.rb|*.js|*.lua) return 0 ;;
		*) return 1 ;;
	esac
}

trim() {
	local value="$1"
	value="${value#"${value%%[![:space:]]*}"}"
	value="${value%"${value##*[![:space:]]}"}"
	printf '%s' "$value"
}

sanitize() {
	local value="$1"
	value="${value//$'\n'/ }"
	value="${value//$'\t'/ }"
	value="${value//|/¦}"
	trim "$value"
}

read_meta_field() {
	local index="$1"
	shift
	local fields=("$@")
	printf '%s' "$(sanitize "${fields[$index]}")"
}

: > "$TMP"
while IFS= read -r script; do
	file="${script#"${SCRIPTS_DIR}/"}"
	[[ -z "$file" || -d "$script" ]] && continue
	[[ -x "$script" ]] || supported_ext "$file" || continue

	meta="$(sed -n 's/^echo "qst! meta //p' "$script" 2>/dev/null | head -n1)"
	if [[ -n "$meta" ]]; then
		meta="${meta%\"}"
		IFS=',' read -r -a parts <<< "$meta"
		name="$(read_meta_field 0 "${parts[@]}")"
		version="$(read_meta_field 1 "${parts[@]}")"
		author="$(read_meta_field 2 "${parts[@]}")"
		if [[ "${#parts[@]}" -gt 3 ]]; then
			description="$(IFS=','; sanitize "${parts[*]:3}")"
		else
			description=""
		fi
	else
		name="$(sanitize "${file%.*}")"
		version=""
		author=""
		description=""
	fi

	printf '%s\t%s\t%s\t%s\t%s\n' "$file" "$name" "$version" "$author" "$description" >> "$TMP"
done < <(find "$SCRIPTS_DIR" -type f | sort)

sort -t $'\t' -k1,1 -o "$TMP" "$TMP"
mv "$TMP" "$OUT"
trap - EXIT

count="$(wc -l < "$OUT" | tr -d ' ')"
echo "Wrote ${count} scripts to ${OUT}"