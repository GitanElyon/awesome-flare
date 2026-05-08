#!/usr/bin/env bash
set -euo pipefail
echo "qst! meta Brightness, 1.0.0, GitanElyon, Adjusts screen brightness."

QUERY="${1:-}"

if ! command -v brightnessctl >/dev/null 2>&1; then
    echo "qst! title Brightness"
    echo "qst! action None"
    echo "  No brightness backend found (need brightnessctl) @meta:center=true|"
    exit 0
fi

list_devices() {
    local backlights
    backlights="$(brightnessctl --list 2>/dev/null | awk -F"'" '/Device/ && /class '\''backlight'\''/ { print $2 }')"
    if [[ -n "$backlights" ]]; then
        printf '%s\n' "$backlights"
        return
    fi

    brightnessctl --list 2>/dev/null | awk -F"'" '/Device/ { print $2 }'
}

get_current_pct() {
    local device="$1"
    brightnessctl -m -d "$device" 2>/dev/null | awk -F',' '
        NF >= 4 {
            if ($4 ~ /%/) {
                gsub(/%/, "", $4)
                print $4
            } else if (NF >= 5 && $3 ~ /^[0-9]+$/ && $5 ~ /^[0-9]+$/ && $5 > 0) {
                printf("%d\n", (($3 / $5) * 100) + 0.5)
            }
        }
    '
}

set_brightness_cmd() {
    local device="$1"
    local percent="$2"
    echo "brightnessctl -d '$device' set '${percent}%'"
}

device_exists() {
    local wanted="$1"
    list_devices | grep -Fxq "$wanted"
}

sanitize_title() {
    local t="$1"
    t="${t//|/¦}"
    printf '%s' "$t"
}

arg="$(echo "$QUERY" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"

if [[ "$arg" == "-h" || "$arg" == "--help" || "$arg" == "help" ]]; then
    echo "qst! title Brightness"
    echo "qst! action None"
    echo "  b!                Show brightness devices|"
    echo "  b! <device>       Open actions for a device|"
    echo "  b! <device> <N>   Set device brightness to N%|"
    exit 0
fi

if [[ "$arg" =~ ^([A-Za-z0-9._:-]+)[[:space:]]+([0-9]{1,3})$ ]]; then
    device="${BASH_REMATCH[1]}"
    target="${BASH_REMATCH[2]}"
    if (( target < 1 )); then target=1; fi
    if (( target > 200 )); then target=200; fi

    if ! list_devices | grep -Fxq "$device"; then
        echo "qst! title Brightness"
        echo "qst! action None"
        echo "  Device not found: $device|"
        exit 0
    fi

    echo "qst! title Brightness"
    echo "qst! action Execute,RefreshResults"
    echo "  Set ${device} to ${target}%|$(set_brightness_cmd "$device" "$target")"
    exit 0
fi

if [[ "$arg" =~ ^([A-Za-z0-9._:-]+)$ ]] && device_exists "$arg"; then
    device="$arg"
    safe_device="$(sanitize_title "$device")"
    current_pct="$(get_current_pct "$device")"

    echo "qst! title Brightness - ${safe_device}"
    echo "qst! action None"
    if [[ -n "$current_pct" ]]; then
        echo "qst! item  Current: ${current_pct}%|Current: ${current_pct}%|None @meta:nonselectable=true @meta:active=true @meta:center=true"
    else
        echo "qst! item  Current: unknown|Current: unknown|None @meta:nonselectable=true @meta:center=true"
    fi
    echo "qst! item  Set to 25%|$(set_brightness_cmd "$device" 25)|Execute,RefreshResults"
    echo "qst! item  Set to 50%|$(set_brightness_cmd "$device" 50)|Execute,RefreshResults"
    echo "qst! item  Set to 75%|$(set_brightness_cmd "$device" 75)|Execute,RefreshResults"
    echo "qst! item  Set to 100%|$(set_brightness_cmd "$device" 100)|Execute,RefreshResults"
    echo "qst! item  Back to device list|Back to device list|PopLastToken @meta:permanent=true"
    exit 0
fi

echo "qst! title Brightness"
echo "qst! action None"

count=0
while IFS= read -r device; do
    [[ -z "$device" ]] && continue

    if [[ -n "$arg" ]]; then
        lower_device="${device,,}"
        lower_arg="${arg,,}"
        [[ "$lower_device" != *"$lower_arg"* ]] && continue
    fi

    count=$((count + 1))
    current_pct="$(get_current_pct "$device")"
    safe_device="$(sanitize_title "$device")"

    if [[ -n "$current_pct" ]]; then
        echo "qst! item  ${safe_device}  (current: ${current_pct}%)|${device} |AppendToQuery @meta:meta=brightness,backlight"
    else
        echo "qst! item  ${safe_device}|${device} |AppendToQuery @meta:meta=brightness,backlight"
    fi
done < <(list_devices)

if (( count == 0 )); then
    if [[ -n "$arg" ]]; then
        echo "  No matching brightness devices for: $arg @meta:center=true|"
    else
        echo "  No brightness devices detected @meta:center=true|"
    fi
fi
