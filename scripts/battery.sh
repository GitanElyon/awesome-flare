#!/usr/bin/env bash
set -euo pipefail
echo "qst! meta Battery Info, 1.0.0, GitanElyon, Shows battery status and health."

echo "qst! title Battery Info"
echo "qst! action None"

base="/sys/class/power_supply"
found=0

read_u64() {
    local p="$1"
    [[ -f "$p" ]] || return 1
    local v
    v="$(tr -d '[:space:]' < "$p" 2>/dev/null || true)"
    [[ "$v" =~ ^[0-9]+$ ]] || return 1
    printf '%s' "$v"
}

emit_info_row() {
    local row="$1"
    [[ -n "$row" ]] && echo "${row} @meta:nonselectable=true|"
}

glyph_rows() {
    case "$1" in
        0) printf '%s' '█▀█|█ █|▀▀▀' ;;
        1) printf '%s' '  █|  █|  ▀' ;;
        2) printf '%s' '▀▀█|█▀▀|▀▀▀' ;;
        3) printf '%s' '▀▀█|▀▀█|▀▀▀' ;;
        4) printf '%s' '█ █|▀▀█|  ▀' ;;
        5) printf '%s' '█▀▀|▀▀█|▀▀▀' ;;
        6) printf '%s' '█▀▀|█▀█|▀▀▀' ;;
        7) printf '%s' '▀▀█|  █|  ▀' ;;
        8) printf '%s' '█▀█|█▀█|▀▀▀' ;;
        9) printf '%s' '█▀█|▀▀█|▀▀▀' ;;
        :) printf '%s' ' ▄ | ▄ |   ' ;;
        %) printf '%s' '▀ █|▄▀ |▀ ▀' ;;
        *) printf '%s' '█▀█|█ █|█▄█' ;;
    esac
}

emit_battery_large() {
    local number="${1}" urgent="${2:-false}"
    local display_text="${number}%"
    local row output glyph char i first_part second_part third_part meta
    meta="@meta:nonselectable=true @meta:center=true"
    [[ "$urgent" == "true" ]] && meta="${meta} @meta:urgent=true @meta:icon=🔋"
    for row in 1 2 3; do
        output=""
        for ((i = 0; i < ${#display_text}; i++)); do
            char="${display_text:i:1}"
            glyph="$(glyph_rows "$char")"
            first_part="${glyph%%|*}"
            second_part="${glyph#*|}"
            second_part="${second_part%%|*}"
            third_part="${glyph##*|}"
            case "$row" in
                1) output+="${first_part} " ;;
                2) output+="${second_part} " ;;
                3) output+="${third_part} " ;;
            esac
        done
        printf 'qst! item  %s|%s|None %s\n' "$output" "$output" "$meta"
    done
}

for bat in "$base"/BAT*; do
    [[ -d "$bat" ]] || continue
    found=1

    name="$(basename "$bat")"
    status="$(cat "$bat/status" 2>/dev/null | tr -d '\n' || echo "Unknown")"
    capacity="$(cat "$bat/capacity" 2>/dev/null | tr -d '\n' || echo "0")"
    model="$(cat "$bat/model_name" 2>/dev/null | tr -d '\n')"
    [[ -z "$model" ]] && model="$name"

    urgent=false
    if [[ "$capacity" =~ ^[0-9]+$ ]] && (( capacity < 10 )); then
        urgent=true
    fi

    emit_battery_large "$capacity" "$urgent"
    emit_info_row "${model}  ·  ${status}"

    energy_now="$(read_u64 "$bat/energy_now" || true)"
    power_now="$(read_u64 "$bat/power_now" || true)"
    energy_full="$(read_u64 "$bat/energy_full" || true)"
    charge_now="$(read_u64 "$bat/charge_now" || true)"
    current_now="$(read_u64 "$bat/current_now" || true)"
    charge_full="$(read_u64 "$bat/charge_full" || true)"

    if [[ -n "$energy_now" && -n "$power_now" && "$power_now" != "0" ]]; then
        if [[ "$status" == "Discharging" ]]; then
            emit_info_row "$(awk -v en="$energy_now" -v pw="$power_now" 'BEGIN { h=en/pw; H=int(h); M=int(((h-H)*60)+0.5); printf("Time Remaining   %dh %dm\n", H, M) }')"
        elif [[ "$status" == "Charging" && -n "$energy_full" && "$energy_full" -gt "$energy_now" ]]; then
            emit_info_row "$(awk -v en="$energy_now" -v full="$energy_full" -v pw="$power_now" 'BEGIN { h=(full-en)/pw; H=int(h); M=int(((h-H)*60)+0.5); printf("Time to Full   %dh %dm\n", H, M) }')"
        fi
    elif [[ -n "$charge_now" && -n "$current_now" && "$current_now" != "0" ]]; then
        if [[ "$status" == "Discharging" ]]; then
            emit_info_row "$(awk -v cn="$charge_now" -v cur="$current_now" 'BEGIN { h=cn/cur; H=int(h); M=int(((h-H)*60)+0.5); printf("Time Remaining   %dh %dm\n", H, M) }')"
        elif [[ "$status" == "Charging" && -n "$charge_full" && "$charge_full" -gt "$charge_now" ]]; then
            emit_info_row "$(awk -v cn="$charge_now" -v full="$charge_full" -v cur="$current_now" 'BEGIN { h=(full-cn)/cur; H=int(h); M=int(((h-H)*60)+0.5); printf("Time to Full   %dh %dm\n", H, M) }')"
        fi
    fi

    if [[ -n "$power_now" ]]; then
        emit_info_row "$(awk -v pw="$power_now" 'BEGIN { printf("Power Usage   %.2f W\n", pw/1000000) }')"
    fi

    if [[ -f "$bat/cycle_count" ]]; then
        cycles="$(tr -d '[:space:]' < "$bat/cycle_count" 2>/dev/null || true)"
        if [[ -n "$cycles" ]]; then
            echo "Cycle Count   ${cycles} @meta:nonselectable=true|"
        fi
    fi
done

if [[ "$found" == "0" ]]; then
    echo "No battery found @meta:nonselectable=true|"
fi
