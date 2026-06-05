#!/usr/bin/env bash
echo "qst! meta Web Search, 1.0.0, GitanElyon, Searches the web in your default browser."
set -euo pipefail

sanitize_text() {
	local text="$1"
	text="${text//$'\n'/ }"
	text="${text//|/¦}"
	printf '%s' "$text"
}

urlencode() {
	local input="$1"
	local encoded=""
	local char
	local LC_ALL=C

	for ((index = 0; index < ${#input}; index++)); do
		char="${input:index:1}"
		case "$char" in
			[a-zA-Z0-9.~_-])
				encoded+="$char"
				;;
			' ')
				encoded+='%20'
				;;
			*)
				printf -v char '%%%02X' "'${char}"
				encoded+="$char"
				;;
		esac
	done

	printf '%s' "$encoded"
}

QUERY="$*"
echo "qst! title  Web Search "

if [[ -z "$QUERY" ]]; then
	echo "qst! action None"
	echo "  Type text to search the web…|"
	exit 0
fi

SEARCH_URL="https://duckduckgo.com/?q=$(urlencode "$QUERY")"
DISPLAY_QUERY="$(sanitize_text "$QUERY")"

echo "qst! action Execute,ExitApp"
printf '  Search the web for: %s|xdg-open %q\n' "$DISPLAY_QUERY" "$SEARCH_URL"