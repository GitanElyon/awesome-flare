#!/usr/bin/env bash
set -euo pipefail
echo "qst! meta Emoji, 1.0.0, opencode, Browses emoji glyphs."

QUERY="${1:-}"
query_lc="${QUERY,,}"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/qst"
CACHE_FILE="$CACHE_DIR/emoji.tsv"

mkdir -p "$CACHE_DIR"

collect_font_files() {
    fc-list 2>/dev/null | awk -F: '
        /[Ee]moji/ {
            print $1
        }
    ' | sort -u
}

# Method 1: otfinfo -u gives codepoint-to-name mappings
build_cache_via_otfinfo() {
    local font_path line codepoint glyph_name

    while IFS= read -r font_path; do
        [[ -z "$font_path" ]] && continue
        while IFS= read -r line; do
            codepoint="${line%%[[:space:]]*}"
            glyph_name="${line#* }"
            glyph_name="${glyph_name#* }"

            case "$codepoint" in
                uni*) codepoint="${codepoint#uni}" ;;
                u*) codepoint="${codepoint#u}" ;;
                *) continue ;;
            esac

            case "$codepoint" in
                ''|*[!0-9A-Fa-f]*) continue ;;
            esac

            printf -v unicode_hex '%08X' "$((16#$codepoint))"
            printf '%s\t%b\n' "${glyph_name}" "\\U${unicode_hex}"
        done < <(otfinfo -u "$font_path" 2>/dev/null)
    done < <(collect_font_files) | sort -u > "$CACHE_FILE"

    [[ -s "$CACHE_FILE" ]]
}

# Method 2: fc-query gives charset ranges when otfinfo is unavailable
build_cache_via_fcquery() {
    local font_path charset range start end dec hexchar

    while IFS= read -r font_path; do
        [[ -z "$font_path" ]] && continue
        charset=$(fc-query --format='%{charset}' "$font_path" 2>/dev/null)
        [[ -z "$charset" ]] && continue

        for range in $charset; do
            start="${range%%-*}"
            end="${range#*-}"
            [[ -z "$end" || "$end" == "$range" ]] && end="$start"

            awk -v s="$start" -v e="$end" 'BEGIN {
                s = strtonum("0x" s)
                e = strtonum("0x" e)
                for (i = s; i <= e; i++) {
                    printf "U+%04X\t\\U%08X\n", i, i
                }
            }'
        done
    done < <(collect_font_files) | sort -u > "$CACHE_FILE"

    [[ -s "$CACHE_FILE" ]]
}

echo "qst! title Emoji"
echo "qst! action CopyToClipboard,ExitApp"

if command -v otfinfo >/dev/null 2>&1; then
    build_cache_via_otfinfo || true
fi

if [[ ! -s "$CACHE_FILE" ]]; then
    if command -v fc-query >/dev/null 2>&1; then
        build_cache_via_fcquery || true
    fi
fi

if [[ ! -s "$CACHE_FILE" ]]; then
    echo "  No emoji found - install an emoji font or lcdf-typetools (for otfinfo)|"
    exit 0
fi

matched=0

while IFS=$'\t' read -r name symbol; do
    [[ -z "$name" || -z "$symbol" ]] && continue

    name_lc="${name,,}"
    if [[ -n "$query_lc" && "$name_lc" != *"$query_lc"* ]]; then
        continue
    fi

    echo "qst! item ${symbol} ${name}|${symbol}|CopyToClipboard,ExitApp"
    matched=$((matched + 1))
done < "$CACHE_FILE"

if (( matched == 0 )); then
    echo "  No emoji found|"
fi
