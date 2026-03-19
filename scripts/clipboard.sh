#!/usr/bin/env bash

QUERY="${1:-}"

# Cache directory and file
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/flare"
CACHE_FILE="$CACHE_DIR/clipboard.txt"
mkdir -p "$CACHE_DIR"

if [[ -z "$QUERY" ]] || [[ ! -f "$CACHE_FILE" ]]; then
    > "$CACHE_FILE"
    
    # Prepend the current active clipboard items first
    if command -v wl-paste >/dev/null 2>&1; then
        content="$(wl-paste -n 2>/dev/null)"
        if [[ -n "$content" ]]; then
              content_clean="${content//$'\n'/ }"
            printf "RAW\t%s\n" "$content_clean" >> "$CACHE_FILE"
        fi
    elif command -v xclip >/dev/null 2>&1; then
        content="$(xclip -selection clipboard -o 2>/dev/null)"
        if [[ -n "$content" ]]; then
            content_clean="${content//$'\n'/ }"
            printf "RAW\t%s\n" "$content_clean" >> "$CACHE_FILE"
        fi
    fi

    # Read external history tools
    if command -v cliphist >/dev/null 2>&1; then
        cliphist list 2>/dev/null | head -n 400 | while IFS=$'\t' read -r id content; do
            [[ -z "$id" || -z "$content" ]] && continue
            printf "CLIPHIST:%s\t%s\n" "$id" "$content"
        done >> "$CACHE_FILE"
    elif command -v wl-clipboard-history >/dev/null 2>&1; then
        wl-clipboard-history list 2>/dev/null | head -n 400 | while IFS=$'\t' read -r content; do
            content_clean="${content//$'\n'/ }"
            printf "RAW\t%s\n" "$content_clean"
        done >> "$CACHE_FILE"
    elif command -v copyq >/dev/null 2>&1; then
        copyq tab clipboard read 2>/dev/null | head -n 400 | while IFS=$'\n' read -r content; do
             content_clean="${content//$'\n'/ }"
             printf "RAW\t%s\n" "$content_clean"
        done >> "$CACHE_FILE"
    fi
fi

echo "f! title Clipboard History"

search="${QUERY,,}"
count=0
declare -A seen

while IFS=$'\t' read -r type_id content; do
    [[ -z "$content" ]] && continue

    if [[ -n "${seen[$content]}" ]]; then
        continue
    fi
    seen["$content"]=1

    lower="${content,,}"
    if [[ -n "$search" && "$lower" != *"$search"* ]]; then
        continue
    fi

    # Preview max 120 chars
    title_raw="${content//$'\n'/ }"
    title="$(printf '%.120s' "$title_raw")"

    if [[ "$type_id" == CLIPHIST:* ]]; then
        id="${type_id#CLIPHIST:}"
        if command -v wl-copy >/dev/null 2>&1; then
            cmd="cliphist decode $id | wl-copy"
        else
            cmd="cliphist decode $id | xclip -selection clipboard -in"
        fi
        echo "f! item ${title}|${cmd}|ExecuteAndExit"
    else
        echo "f! item ${title}|${content}|CopyToClipboardAndExit"
    fi

    count=$((count + 1))
    if (( count >= 100 )); then
        break
    fi
done < "$CACHE_FILE"

if (( count == 0 )); then
    echo "f! action None"
    echo "  No clipboard entries found|"
fi
