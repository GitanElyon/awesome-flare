#!/usr/bin/env bash
echo "qst! meta Symbols, 2.0.0, GitanElyon, Browses Nerd Fonts symbols."

QUERY="${1:-}"
query_lc="${QUERY,,}"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/qst"
CACHE_FILE="$CACHE_DIR/symbols-nerdfont.tsv"

mkdir -p "$CACHE_DIR"

otfinfo_cmd() {
    if command -v otfinfo >/dev/null 2>&1; then
        otfinfo "$@"
    else
        nix shell nixpkgs#lcdf-typetools -c otfinfo "$@"
    fi
}

collect_font_files() {
    fc-list 2>/dev/null | awk -F: '
        /Nerd Font/ {
            print $1
        }
    ' | sort -u
}

build_cache() {
    local font_path codepoint glyph_name line

    while IFS= read -r font_path; do
        [[ -z "$font_path" ]] && continue
        while IFS= read -r line; do
            codepoint="${line%%[[:space:]]*}"
            glyph_name="${line#* }"
            glyph_name="${glyph_name#* }"

            case "$glyph_name" in
                cod-*|dev-*|fa-*|fae-*|iec-*|linux-*|oct-*|ple-*|pom-*|seti-*|md-*|custom-*)
                    ;;
                *)
                    continue
                    ;;
            esac

            case "$codepoint" in
                uni*) codepoint="${codepoint#uni}" ;;
                u*) codepoint="${codepoint#u}" ;;
                *) continue ;;
            esac

            case "$codepoint" in
                ''|*[!0-9A-Fa-f]*) continue ;;
            esac

            printf -v unicode_hex '%08X' "$((16#$codepoint))"
            printf '%s\t%b\n' "nf-${glyph_name}" "\\U${unicode_hex}"
        done < <(otfinfo_cmd -u "$font_path" 2>/dev/null)
    done < <(collect_font_files) | sort -u > "$CACHE_FILE"

    [[ -s "$CACHE_FILE" ]]
}

echo "qst! title Symbols"
echo "qst! action CopyToClipboard,ExitApp"

if [[ ! -s "$CACHE_FILE" ]]; then
    if ! build_cache; then
        echo "  Unable to load Nerd Fonts symbols|"
        exit 0
    fi
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
    echo "  No Nerd Fonts symbols found|"
fi
