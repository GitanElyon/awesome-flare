#!/usr/bin/env bash
set -euo pipefail
echo "qst! meta Media, 1.0.0, GitanElyon, Control currently playing media."
QUERY="${1:-}"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

if ! command_exists playerctl; then
    echo "qst! title  Media "
    echo "qst! action None"
    echo "  playerctl not found|"
    echo "  Install: pacman -S playerctl @meta:nonselectable=true @meta:center=true|"
    exit 0
fi

playerctl_status() {
    playerctl status 2>/dev/null || echo "No Player"
}

get_metadata() {
    local field="$1"
    playerctl metadata "$field" 2>/dev/null || echo ""
}

status="$(playerctl_status)"

if [[ "$status" == "No Player" ]]; then
    echo "qst! title  Media - No Player "
    echo "qst! action None"
    echo "  No active media player found @meta:nonselectable=true @meta:center=true|"
    exit 0
fi

artist="$(get_metadata artist)"
title="$(get_metadata title)"
album="$(get_metadata album)"
player_name="$(playerctl -f '{{playerName}}' metadata 2>/dev/null || echo "unknown")"

if [[ -n "$artist" && -n "$title" ]]; then
    display="${artist} - ${title}"
elif [[ -n "$title" ]]; then
    display="$title"
else
    display="Unknown Track"
fi

if [[ -n "$album" ]]; then
    short_display="${display} (${album})"
else
    short_display="$display"
fi

if (( ${#short_display} > 50 )); then
    title_text=" ${short_display:0:47}... "
else
    title_text=" ${short_display} "
fi

echo "qst! title ${title_text}"

arg="${QUERY# }"

if [[ "$arg" == "-h" || "$arg" == "--help" || "$arg" == "help" ]]; then
    echo "qst! action None"
    echo "  media              Show currently playing @meta:nonselectable=true|"
    echo "  media p            Toggle play/pause @meta:nonselectable=true|"
    echo "  media play         Resume playback @meta:nonselectable=true|"
    echo "  media pause        Pause playback @meta:nonselectable=true|"
    echo "  media next         Next track @meta:nonselectable=true|"
    echo "  media prev         Previous track @meta:nonselectable=true|"
    echo "  media stop         Stop playback @meta:nonselectable=true|"
    echo "  media shuffle      Toggle shuffle @meta:nonselectable=true|"
    echo "  media repeat       Cycle repeat mode @meta:nonselectable=true|"
    echo "  media pos N        Seek to position in seconds @meta:nonselectable=true|"
    echo "  media vol N        Set volume (0-100) @meta:nonselectable=true|"
    echo "  media players      List available players @meta:nonselectable=true|"
    echo "  media switch P     Switch to player P @meta:nonselectable=true|"
    exit 0
fi

case "$arg" in
    p)
        echo "qst! action Execute,RefreshResults"
        echo "  Toggle Play/Pause|playerctl play-pause"
        exit 0
        ;;
    play)
        echo "qst! action Execute,RefreshResults"
        echo "  Resume Playback|playerctl play"
        exit 0
        ;;
    pause)
        echo "qst! action Execute,RefreshResults"
        echo "  Pause|playerctl pause"
        exit 0
        ;;
    next|n)
        echo "qst! action Execute,RefreshResults"
        echo "  Next Track|playerctl next"
        exit 0
        ;;
    prev|previous|b)
        echo "qst! action Execute,RefreshResults"
        echo "  Previous Track|playerctl previous"
        exit 0
        ;;
    stop|s)
        echo "qst! action Execute,RefreshResults"
        echo "  Stop|playerctl stop"
        exit 0
        ;;
    shuffle)
        echo "qst! action Execute,RefreshResults"
        echo "  Toggle Shuffle|playerctl shuffle"
        exit 0
        ;;
    repeat)
        echo "qst! action Execute,RefreshResults"
        echo "  Cycle Repeat|playerctl loop"
        exit 0
        ;;
    position|pos|seek)
        pos_arg="${QUERY#* }"
        if [[ "$pos_arg" =~ ^[0-9]+$ ]]; then
            echo "qst! action Execute,RefreshResults"
            echo "  Seek to ${pos_arg}s|playerctl position ${pos_arg}"
        else
            echo "qst! action None"
            echo "  Usage: media pos <seconds> @meta:nonselectable=true @meta:center=true|"
        fi
        exit 0
        ;;
    vol|volume)
        vol_arg="${QUERY#* }"
        if [[ "$vol_arg" =~ ^[0-9]+$ ]]; then
            echo "qst! action Execute,RefreshResults"
            echo "  Set Volume to ${vol_arg}%|playerctl volume $(awk -v v="$vol_arg" 'BEGIN { printf("%.2f", v/100) }')"
        else
            echo "qst! action None"
            echo "  Usage: media vol <0-100> @meta:nonselectable=true @meta:center=true|"
        fi
        exit 0
        ;;
    players|pl)
        echo "qst! title  Media - Players "
        echo "qst! action Execute,RefreshResults"
        playerctl -l 2>/dev/null | while IFS= read -r p; do
            [[ -z "$p" ]] && continue
            if [[ "$p" == "$player_name" ]]; then
                echo "  ${p} *|playerctl -p ${p} metadata"
            else
                echo "  ${p}|playerctl -p ${p} metadata"
            fi
        done
        exit 0
        ;;
    switch)
        switch_arg="${QUERY#* }"
        if [[ -n "$switch_arg" ]]; then
            echo "qst! action Execute,RefreshResults"
            echo "  Switch to ${switch_arg}|playerctl -p ${switch_arg} metadata"
        else
            echo "qst! action None"
            echo "  Usage: media switch <player-name> @meta:nonselectable=true @meta:center=true|"
        fi
        exit 0
        ;;
esac

duration_us="$(playerctl metadata mpris:length 2>/dev/null || echo "0")"
position_s="$(playerctl position 2>/dev/null || echo "0")"

format_time() {
    local sec="$1"
    if [[ "$sec" =~ ^[0-9]+$ ]] && (( sec > 0 )); then
        local h=$(( sec / 3600 ))
        local m=$(( (sec % 3600) / 60 ))
        local s=$(( sec % 60 ))
        if (( h > 0 )); then
            printf "%d:%02d:%02d" "$h" "$m" "$s"
        else
            printf "%d:%02d" "$m" "$s"
        fi
    else
        echo "0:00"
    fi
}

duration_s="$(awk -v d="${duration_us%.*}" 'BEGIN { printf("%d", d/1000000) }')"
pos_fmt="$(format_time "${position_s%.*}")"
dur_fmt="$(format_time "$duration_s")"

current_vol="$(playerctl volume 2>/dev/null || echo "0")"
vol_pct="$(awk -v v="$current_vol" 'BEGIN { printf("%d", v*100+0.5) }')"

echo "qst! action Execute,RefreshResults"
if [[ "$status" == "Playing" ]]; then
    echo "  Now Playing @meta:nonselectable=true @meta:active=true @meta:center=true|"
else
    echo "  Paused @meta:nonselectable=true @meta:center=true|"
fi

if [[ -n "$artist" ]]; then
    echo "  Artist: ${artist} @meta:nonselectable=true|"
fi
if [[ -n "$album" ]]; then
    echo "  Album: ${album} @meta:nonselectable=true|"
fi

echo "  ${pos_fmt} / ${dur_fmt}  Vol: ${vol_pct}% @meta:nonselectable=true @meta:center=true|"
echo "  Player: ${player_name} @meta:nonselectable=true @meta:center=true|"

if [[ "$status" == "Playing" ]]; then
    echo "  Pause|playerctl play-pause"
else
    echo "  Play|playerctl play-pause"
fi
echo "  Next Track|playerctl next"
echo "  Previous Track|playerctl previous"
echo "  Stop|playerctl stop"
echo "  Toggle Shuffle|playerctl shuffle"
echo "  Cycle Repeat|playerctl loop"
