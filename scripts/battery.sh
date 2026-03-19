#!/usr/bin/env bash

echo "f! title Battery Info"
echo "f! action None"

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

for bat in "$base"/BAT*; do
    [[ -d "$bat" ]] || continue
    found=1

    name="$(basename "$bat")"
    status="$(cat "$bat/status" 2>/dev/null | tr -d '\n' || echo "Unknown")"
    capacity="$(cat "$bat/capacity" 2>/dev/null | tr -d '\n' || echo "0")"
    model="$(cat "$bat/model_name" 2>/dev/null | tr -d '\n')"
    [[ -z "$model" ]] && model="$name"

    echo "${model} (${capacity}%)  ${status}|"

    energy_now="$(read_u64 "$bat/energy_now" || true)"
    power_now="$(read_u64 "$bat/power_now" || true)"
    energy_full="$(read_u64 "$bat/energy_full" || true)"
    charge_now="$(read_u64 "$bat/charge_now" || true)"
    current_now="$(read_u64 "$bat/current_now" || true)"
    charge_full="$(read_u64 "$bat/charge_full" || true)"

    if [[ -n "$energy_now" && -n "$power_now" && "$power_now" != "0" ]]; then
        if [[ "$status" == "Discharging" ]]; then
            awk -v en="$energy_now" -v pw="$power_now" 'BEGIN { h=en/pw; H=int(h); M=int(((h-H)*60)+0.5); printf("Time Remaining   %dh %dm\n", H, M) }'
        elif [[ "$status" == "Charging" && -n "$energy_full" && "$energy_full" -gt "$energy_now" ]]; then
            awk -v en="$energy_now" -v full="$energy_full" -v pw="$power_now" 'BEGIN { h=(full-en)/pw; H=int(h); M=int(((h-H)*60)+0.5); printf("Time to Full   %dh %dm\n", H, M) }'
        fi | while IFS= read -r line; do echo "$line|"; done
    elif [[ -n "$charge_now" && -n "$current_now" && "$current_now" != "0" ]]; then
        if [[ "$status" == "Discharging" ]]; then
            awk -v cn="$charge_now" -v cur="$current_now" 'BEGIN { h=cn/cur; H=int(h); M=int(((h-H)*60)+0.5); printf("Time Remaining   %dh %dm\n", H, M) }'
        elif [[ "$status" == "Charging" && -n "$charge_full" && "$charge_full" -gt "$charge_now" ]]; then
            awk -v cn="$charge_now" -v full="$charge_full" -v cur="$current_now" 'BEGIN { h=(full-cn)/cur; H=int(h); M=int(((h-H)*60)+0.5); printf("Time to Full   %dh %dm\n", H, M) }'
        fi | while IFS= read -r line; do echo "$line|"; done
    fi

    if [[ -n "$power_now" ]]; then
        awk -v pw="$power_now" 'BEGIN { printf("Power Usage   %.2f W\n", pw/1000000) }' | while IFS= read -r line; do echo "$line|"; done
    fi

    if [[ -f "$bat/cycle_count" ]]; then
        cycles="$(tr -d '[:space:]' < "$bat/cycle_count" 2>/dev/null || true)"
        if [[ -n "$cycles" ]]; then
            echo "Cycle Count   ${cycles}|"
        fi
    fi
done

if [[ "$found" == "0" ]]; then
    echo "No battery found|"
fi
