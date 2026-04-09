#!/usr/bin/env bash
QUERY="${1:-}"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

detect_backend() {
    if command_exists wpctl; then
        echo "wpctl"
    elif command_exists pactl; then
        echo "pactl"
    elif command_exists amixer; then
        echo "amixer"
    else
        echo ""
    fi
}

get_volume_info() {
    if command_exists wpctl; then
        local out
        out="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)"
        if [[ "$out" =~ ^Volume:\ ([0-9.]+) ]]; then
            local raw="${BASH_REMATCH[1]}"
            local pct
            pct="$(awk -v v="$raw" 'BEGIN { printf("%d", (v*100)+0.5) }')"
            if [[ "$out" == *"[MUTED]"* ]]; then
                echo "$pct 1"
            else
                echo "$pct 0"
            fi
            return
        fi
    fi

    if command_exists pactl; then
        local vol mute
        vol="$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | sed -n 's|.* / *\([0-9]\+\)%.*|\1|p' | head -n1)"
        if pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -qi "yes"; then
            mute="1"
        else
            mute="0"
        fi
        if [[ -n "$vol" ]]; then
            echo "$vol $mute"
            return
        fi
    fi

    if command_exists amixer; then
        local out vol
        out="$(amixer get Master 2>/dev/null || true)"
        vol="$(printf '%s\n' "$out" | sed -n 's|.*\[\([0-9]\+\)%\].*|\1|p' | head -n1)"
        if [[ -n "$vol" ]]; then
            if printf '%s\n' "$out" | grep -q "\[off\]"; then
                echo "$vol 1"
            else
                echo "$vol 0"
            fi
            return
        fi
    fi

    echo "-1 -1"
}

volume_bar() {
    local v="$1"
    local width=20
    if (( v < 0 )); then v=0; fi
    if (( v > 100 )); then v=100; fi
    local filled=$(( (v*width + 50) / 100 ))
    local empty=$(( width - filled ))
    printf '['
    printf '█%.0s' $(seq 1 "$filled" 2>/dev/null)
    printf '░%.0s' $(seq 1 "$empty" 2>/dev/null)
    printf ']'
}

set_volume_cmd() {
    local backend="$1"
    local target="$2"
    case "$backend" in
        wpctl) echo "wpctl set-volume @DEFAULT_AUDIO_SINK@ ${target}%" ;;
        pactl) echo "pactl set-sink-volume @DEFAULT_SINK@ ${target}%" ;;
        amixer) echo "amixer set Master ${target}%" ;;
    esac
}

adjust_volume_cmd() {
    local backend="$1"
    local delta="$2"
    case "$backend" in
        wpctl)
            if (( delta >= 0 )); then
                echo "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ ${delta}%+"
            else
                echo "wpctl set-volume @DEFAULT_AUDIO_SINK@ ${delta#-}%-"
            fi
            ;;
        pactl)
            if (( delta >= 0 )); then
                echo "pactl set-sink-volume @DEFAULT_SINK@ +${delta}%"
            else
                echo "pactl set-sink-volume @DEFAULT_SINK@ -${delta#-}%"
            fi
            ;;
        amixer)
            if (( delta >= 0 )); then
                echo "amixer set Master ${delta}%+"
            else
                echo "amixer set Master ${delta#-}%-"
            fi
            ;;
    esac
}

mute_toggle_cmd() {
    case "$1" in
        wpctl) echo "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" ;;
        pactl) echo "pactl set-sink-mute @DEFAULT_SINK@ toggle" ;;
        amixer) echo "amixer set Master toggle" ;;
    esac
}

list_sinks() {
    local backend="$1"
    if [[ "$backend" == "wpctl" ]]; then
        wpctl status 2>/dev/null | awk '
            BEGIN { in_audio=0; in_sinks=0 }
            /^Audio/ { in_audio=1; next }
            in_audio && /Sinks:/ { in_sinks=1; next }
            in_sinks {
                line=$0
                gsub(/^\s+/, "", line)
                if (line == "") { in_audio=0; in_sinks=0; next }
                gsub(/^\*/, "", line)
                gsub(/^\s+/, "", line)
                split(line, parts, ".")
                if (length(parts[1]) > 0) {
                    id=parts[1]
                    sub(/^[^.]*\.\s*/, "", line)
                    sub(/\s*\[.*/, "", line)
                    gsub(/^\s+|\s+$/, "", line)
                    if (id != "" && line != "") print id "\t" line
                }
            }
        '
    elif [[ "$backend" == "pactl" ]]; then
        pactl list short sinks 2>/dev/null | awk -F'\t' '{ if (NF >= 2) print $2 "\t" $2 }'
    fi
}

backend="$(detect_backend)"
if [[ -z "$backend" ]]; then
    echo "qst! title  Volume "
    echo "qst! action None"
    echo "  No audio backend found (requires wpctl, pactl, or amixer) @meta:nonselectable=true|"
    exit 0
fi

read -r current_vol muted < <(get_volume_info)
if [[ "$current_vol" == "-1" ]]; then
    title=" Volume "
else
    if [[ "$muted" == "1" ]]; then
        title=" Volume ${current_vol}% [MUTED] "
    else
        title=" Volume ${current_vol}% "
    fi
fi

arg="${QUERY# }"
echo "qst! title ${title}"

if [[ "$arg" == "-h" || "$arg" == "--help" || "$arg" == "help" ]]; then
    echo "qst! action None"
    echo "  v!           Open volume menu @meta:nonselectable=true|"
    echo "  v! -h        Show this help @meta:nonselectable=true|"
    echo "  v! +N        Increase volume by N%   (e.g. v! +10) @meta:nonselectable=true|"
    echo "  v! -N        Decrease volume by N%   (e.g. v! -5) @meta:nonselectable=true|"
    echo "  v! N         Set volume to N%        (e.g. v! 75) @meta:nonselectable=true|"
    echo "  v! mute      Toggle mute @meta:nonselectable=true|"
    echo "  v! devices   List and switch output devices @meta:nonselectable=true|"
    exit 0
fi

if [[ "$arg" == "mute" || "$arg" == "m" ]]; then
    echo "qst! action Execute,RefreshResults"
    if [[ "$muted" == "1" ]]; then
        echo "  Unmute|$(mute_toggle_cmd "$backend")"
    else
        echo "  Mute|$(mute_toggle_cmd "$backend")"
    fi
    exit 0
fi

if [[ "$arg" == "devices" || "$arg" == "d" ]]; then
    echo "qst! title  Volume - Output Devices "
    echo "qst! action Execute,RefreshResults"
    local_count=0
    while IFS=$'\t' read -r sink_id sink_name; do
        [[ -z "$sink_id" || -z "$sink_name" ]] && continue
        local_count=$((local_count+1))
        if [[ "$backend" == "wpctl" ]]; then
            echo "  ${sink_name}|wpctl set-default ${sink_id}"
        elif [[ "$backend" == "pactl" ]]; then
            echo "  ${sink_name}|pactl set-default-sink ${sink_id}"
        fi
    done < <(list_sinks "$backend")
    if (( local_count == 0 )); then
        echo "qst! action None"
        echo "  No output devices found @meta:nonselectable=true|"
    fi
    exit 0
fi

if [[ "$arg" =~ ^\+([0-9]+)$ ]]; then
    delta="${BASH_REMATCH[1]}"
    echo "qst! action Execute,RefreshResults"
    echo "  Increase volume by ${delta}%|$(adjust_volume_cmd "$backend" "$delta")"
    exit 0
fi

if [[ "$arg" =~ ^-([0-9]+)$ ]]; then
    delta="${BASH_REMATCH[1]}"
    echo "qst! action Execute,RefreshResults"
    echo "  Decrease volume by ${delta}%|$(adjust_volume_cmd "$backend" "-$delta")"
    exit 0
fi

if [[ "$arg" =~ ^[0-9]+$ ]]; then
    target="$arg"
    if (( target > 150 )); then target=150; fi
    echo "qst! action Execute,RefreshResults"
    echo "  Set volume to ${target}%|$(set_volume_cmd "$backend" "$target")"
    exit 0
fi

echo "qst! action Execute,RefreshResults"
if [[ "$current_vol" == "-1" ]]; then
    echo "  Volume status unavailable @meta:nonselectable=true|"
else
    bar="$(volume_bar "$current_vol")"
    if [[ "$muted" == "1" ]]; then
        echo "  ${current_vol}% ${bar} [MUTED] @meta:nonselectable=true @meta:urgent=true|"
    else
        echo "  ${current_vol}% ${bar} @meta:nonselectable=true @meta:active=true|"
    fi
fi
echo "  Volume Up  (+5%)|$(adjust_volume_cmd "$backend" 5)"
echo "  Volume Down (-5%)|$(adjust_volume_cmd "$backend" -5)"
if [[ "$muted" == "1" ]]; then
    echo "  Unmute|$(mute_toggle_cmd "$backend")"
else
    echo "  Mute|$(mute_toggle_cmd "$backend")"
fi
echo "  Set to 25%|$(set_volume_cmd "$backend" 25)"
echo "  Set to 50%|$(set_volume_cmd "$backend" 50)"
echo "  Set to 75%|$(set_volume_cmd "$backend" 75)"
echo "  Set to 100%|$(set_volume_cmd "$backend" 100)"
echo "  Output Devices (v! devices) @meta:nonselectable=true @meta:permanent=true|"
