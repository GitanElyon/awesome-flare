#!/usr/bin/env bash
echo "qst! meta Web Search, 1.1.0, GitanElyon, Searches the web in your default browser."
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

is_url() {
	local text="$1"
	[[ "$text" =~ ^https?:// ]]
}

resolve_url() {
	local text="$1"
	if is_url "$text"; then
		printf '%s' "$text"
	else
		printf 'https://%s' "$text"
	fi
}

get_search_url() {
	local browser
	browser=$(xdg-settings get default-web-browser 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")
	case "$browser" in
		*chrome*|*chromium*|*google*|*vivaldi*|*opera*)
			printf 'https://www.google.com/search?q='
			;;
		*brave*)
			printf 'https://search.brave.com/search?q='
			;;
		*edge*|*msedge*)
			printf 'https://www.bing.com/search?q='
			;;
		*yandex*)
			printf 'https://yandex.com/search/?text='
			;;
		*)
			printf 'https://duckduckgo.com/?q='
			;;
	esac
}

show_help() {
	cat <<'EOF'
  Web Search — opens queries in your browser

  Flags (first argument):
    h       Show this help text
    s       Force search (send query to search engine)
    u       Force URL (open as website, prepends https:// if needed)

  Without a flag, auto-detects:
    - URLs starting with http:// or https:// are opened directly
    - Everything else is sent to the browser via its search URL
EOF
}

RAW_QUERY="$*"
echo "qst! title  Web Search "

FLAG=""
QUERY="$RAW_QUERY"
if [[ "$RAW_QUERY" =~ ^[hsu]\  ]]; then
	FLAG="${RAW_QUERY:0:1}"
	QUERY="${RAW_QUERY:2}"
fi

if [[ "$FLAG" == "h" ]]; then
	echo "qst! action None"
	show_help
	exit 0
fi

if [[ -z "$QUERY" ]]; then
	echo "qst! action None"
	echo "  Type text to search the web…|"
	exit 0
fi

if [[ "$FLAG" == "u" ]]; then
	URL="$(resolve_url "$QUERY")"
	echo "qst! action Execute,ExitApp"
	printf '  Open URL: %s|xdg-open %q\n' "$(sanitize_text "$URL")" "$URL"
	exit 0
fi

SEARCH_URL="$(get_search_url)$(urlencode "$QUERY")"
DISPLAY_QUERY="$(sanitize_text "$QUERY")"

if [[ "$FLAG" == "s" ]] || ! is_url "$QUERY"; then
	echo "qst! action Execute,ExitApp"
	printf '  Search the web for: %s|xdg-open %q\n' "$DISPLAY_QUERY" "$SEARCH_URL"
	exit 0
fi

echo "qst! action Execute,ExitApp"
printf '  Open URL: %s|xdg-open %q\n' "$(sanitize_text "$QUERY")" "$QUERY"
