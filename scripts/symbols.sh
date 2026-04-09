#!/usr/bin/env bash

QUERY="${1:-}"
query_lc="${QUERY,,}"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/qst"
CACHE_FILE="$CACHE_DIR/symbols.txt"
mkdir -p "$CACHE_DIR"

if [[ ! -f "$CACHE_FILE" ]]; then
    > "$CACHE_FILE"
    
    repo_symbols="$(cd "$(dirname "$0")/.." && pwd)/assets/symbols.json"
    dev_symbols="$HOME/Projects/qst/assets/symbols.json"
    
    source_json=""
    if [[ -f "$HOME/.config/qst/symbols.json" ]]; then
        source_json="$HOME/.config/qst/symbols.json"
    elif [[ -f "$repo_symbols" ]]; then
        source_json="$repo_symbols"
    elif [[ -f "$dev_symbols" ]]; then
        source_json="$dev_symbols"
    elif [[ -f "/usr/share/qst/symbols.json" ]]; then
        source_json="/usr/share/qst/symbols.json"
    fi
    
    if [[ -n "$source_json" && -f "$source_json" ]]; then
        awk '
        {
            while (match($0, /\[[[:space:]]*"([^"\\]|\\.)+"[[:space:]]*,[[:space:]]*"([^"\\]|\\.)+"[[:space:]]*\]/)) {
                chunk = substr($0, RSTART, RLENGTH)
                gsub(/^\[[[:space:]]*"/, "", chunk)
                gsub(/"[[:space:]]*,[[:space:]]*"/, "\t", chunk)
                gsub(/"[[:space:]]*\]$/, "", chunk)
                gsub(/\\"/, "\"", chunk)
                print chunk
                $0 = substr($0, RSTART + RLENGTH)
            }
        }
        ' "$source_json" > "$CACHE_FILE"
    else
        # Start generating unicode blocks dynamically if JSON is fully missing
        for ((i=0x1F600; i<=0x1F64F; i++)); do printf "Emoji %X\t\\U%08X\n" "$i" "$i"; done >> "$CACHE_FILE"
        for ((i=0x1F680; i<=0x1F6C5; i++)); do printf "Transport %X\t\\U%08X\n" "$i" "$i"; done >> "$CACHE_FILE"
        for ((i=0x1F300; i<=0x1F5FF; i++)); do printf "Misc %X\t\\U%08X\n" "$i" "$i"; done >> "$CACHE_FILE"
        for ((i=0x2600; i<=0x26FF; i++)); do printf "Symbol %X\t\\U%08X\n" "$i" "$i"; done >> "$CACHE_FILE"
        for ((i=0x2700; i<=0x27BF; i++)); do printf "Dingbat %X\t\\U%08X\n" "$i" "$i"; done >> "$CACHE_FILE"
        for ((i=0x2200; i<=0x22FF; i++)); do printf "Math %X\t\\U%08X\n" "$i" "$i"; done >> "$CACHE_FILE"
        for ((i=0x2190; i<=0x21FF; i++)); do printf "Arrow %X\t\\U%08X\n" "$i" "$i"; done >> "$CACHE_FILE"
        for ((i=0x2500; i<=0x257F; i++)); do printf "Box %X\t\\U%08X\n" "$i" "$i"; done >> "$CACHE_FILE"
    fi
fi

is_favorite() {
    local name="$1"
    local hist="$HOME/.config/qst/history.toml"
    [[ -f "$hist" ]] || return 1
    grep -q "favorite_symbols" "$hist" || return 1
    grep -q "\"$name\"" "$hist"
}

echo "qst! title Symbols"
echo "qst! action CopyToClipboard,ExitApp"

count=0

while IFS=$'\t' read -r name symbol; do
    [[ -z "$name" || -z "$symbol" ]] && continue

    name_lc="${name,,}"
    if [[ -n "$query_lc" && "$name_lc" != *"$query_lc"* ]]; then
        continue
    fi

    if is_favorite "$name"; then
        title="★ ${symbol} ${name}"
        row_meta=" @meta:active=true"
    else
        title="${symbol} ${name}"
        row_meta=""
    fi

    echo "qst! item ${title}|${symbol} @meta:meta=unicode,symbol${row_meta}"
    
    count=$((count + 1))
    if (( count >= 300 )); then
        break
    fi
done < "$CACHE_FILE"

if (( count == 0 )); then
    echo "  No symbols found|"
fi
