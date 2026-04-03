#!/usr/bin/env bash

QUERY="${1:-}"
echo "qst! title Clipboard History"

copy_backend=""
if command -v wl-copy >/dev/null 2>&1; then
    copy_backend="wl-copy"
elif command -v xclip >/dev/null 2>&1; then
    copy_backend="xclip"
fi

if [[ -z "$copy_backend" ]]; then
    echo "qst! action None"
    echo "  No clipboard writer found (need wl-copy or xclip)|"
    exit 0
fi

emit_raw_item() {
    local content="$1"
    local active_meta="${2:-}"
    [[ -z "$content" ]] && return

    local title encoded cmd lower
    title="${content//$'\n'/ }"
    title="${title//|/¦}"
    title="$(printf '%.120s' "$title")"
    lower="${title,,}"

    if [[ -n "$search" && "$lower" != *"$search"* ]]; then
        return
    fi
    if [[ -n "${seen[$title]}" ]]; then
        return
    fi
    seen["$title"]=1

    encoded="$(printf '%s' "$content" | base64 -w 0)"
    if [[ "$copy_backend" == "wl-copy" ]]; then
        cmd="tmp=\$(mktemp); base64 -d <<< '$encoded' > \"\$tmp\"; wl-copy < \"\$tmp\"; rm -f \"\$tmp\""
    else
        cmd="tmp=\$(mktemp); base64 -d <<< '$encoded' > \"\$tmp\"; xclip -selection clipboard -in < \"\$tmp\"; rm -f \"\$tmp\""
    fi

    echo "qst! item ${title}|${cmd}|ExecuteAndExit${active_meta}"
    count=$((count + 1))
}

emit_cliphist_item() {
    local id="$1"
    local content="$2"
    [[ -z "$id" || -z "$content" ]] && return

    local title lower cmd
    title="${content//$'\n'/ }"
    title="${title//|/¦}"
    title="$(printf '%.120s' "$title")"
    lower="${title,,}"

    if [[ -n "$search" && "$lower" != *"$search"* ]]; then
        return
    fi
    if [[ -n "${seen[$title]}" ]]; then
        return
    fi
    seen["$title"]=1

    if [[ "$copy_backend" == "wl-copy" ]]; then
        cmd="tmp=\$(mktemp); cliphist decode $id > \"\$tmp\"; wl-copy < \"\$tmp\"; rm -f \"\$tmp\""
    else
        cmd="tmp=\$(mktemp); cliphist decode $id > \"\$tmp\"; xclip -selection clipboard -in < \"\$tmp\"; rm -f \"\$tmp\""
    fi

    echo "qst! item ${title}|${cmd}|ExecuteAndExit"
    count=$((count + 1))
}

search="${QUERY,,}"
count=0
declare -A seen

if command -v wl-paste >/dev/null 2>&1; then
    current_clip="$(wl-paste -n 2>/dev/null)"
    emit_raw_item "$current_clip" " @meta:active=true"
elif command -v xclip >/dev/null 2>&1; then
    current_clip="$(xclip -selection clipboard -o 2>/dev/null)"
    emit_raw_item "$current_clip" " @meta:active=true"
fi

if command -v cliphist >/dev/null 2>&1; then
    while IFS= read -r line; do
        (( count >= 100 )) && break
        id="${line%%$'\t'*}"
        content="${line#*$'\t'}"
        [[ -z "$line" || "$id" == "$line" ]] && continue
        emit_cliphist_item "$id" "$content"
    done < <(cliphist list 2>/dev/null | head -n 400)
elif command -v wl-clipboard-history >/dev/null 2>&1; then
    while IFS= read -r content; do
        (( count >= 100 )) && break
        emit_raw_item "$content"
    done < <(wl-clipboard-history list 2>/dev/null | head -n 400)
elif command -v copyq >/dev/null 2>&1; then
    while IFS= read -r content; do
        (( count >= 100 )) && break
        emit_raw_item "$content"
    done < <(copyq tab clipboard read 2>/dev/null | head -n 400)
fi

if (( count == 0 )); then
    echo "qst! action None"
    echo "  No clipboard entries found|"
fi
