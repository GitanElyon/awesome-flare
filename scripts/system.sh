#!/usr/bin/env bash
echo "qst! meta System Monitor, 1.0.0, GitanElyon, Shows CPU, memory, disk, network, and process usage."
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/qst/storage/system"
STATE_FILE="$STATE_DIR/state.tsv"

ensure_store() {
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
}

emit_row() {
    local title="$1"
    local value="$2"
    local meta="${3:-}"
    local display
    display="$(sanitize_text "$value")"
    printf 'qst! item  %s  %s|%s|None @meta:nonselectable=true @meta:display=%s  %s%s\n' "$title" "$display" "$title" "$title" "$display" "$meta"
}

emit_center_row() {
    local text="$1"
    printf 'qst! item  %s|%s|None @meta:nonselectable=true @meta:center=true\n' "$text" "$text"
}

sanitize_text() {
    local text="$1"
    text="${text//$'\n'/ }"
    text="${text//|/¦}"
    printf '%s' "$text"
}

human_bytes() {
    local bytes="${1:-0}"
    awk -v bytes="$bytes" 'BEGIN {
        split("B KiB MiB GiB TiB PiB", units, " ")
        if (bytes < 0) {
            bytes = 0
        }
        unit = 1
        while (bytes >= 1024 && unit < 6) {
            bytes /= 1024
            unit++
        }
        if (unit == 1) {
            printf "%.0f %s", bytes, units[unit]
        } else {
            printf "%.1f %s", bytes, units[unit]
        }
    }'
}

human_rate() {
    local bytes_per_second="${1:-0}"
    awk -v bytes="$bytes_per_second" 'BEGIN {
        split("B KiB MiB GiB TiB PiB", units, " ")
        if (bytes < 0) {
            bytes = 0
        }
        unit = 1
        while (bytes >= 1024 && unit < 6) {
            bytes /= 1024
            unit++
        }
        if (unit == 1) {
            printf "%.0f %s/s", bytes, units[unit]
        } else {
            printf "%.1f %s/s", bytes, units[unit]
        }
    }'
}

format_duration() {
    local total_seconds="${1:-0}"
    local days hours minutes seconds

    days=$((total_seconds / 86400))
    hours=$(((total_seconds % 86400) / 3600))
    minutes=$(((total_seconds % 3600) / 60))
    seconds=$((total_seconds % 60))

    if (( days > 0 )); then
        printf '%dd %dh %dm' "$days" "$hours" "$minutes"
    elif (( hours > 0 )); then
        printf '%dh %dm' "$hours" "$minutes"
    elif (( minutes > 0 )); then
        printf '%dm %ds' "$minutes" "$seconds"
    else
        printf '%ds' "$seconds"
    fi
}

read_cpu_sample() {
    local user nice system idle iowait irq softirq steal guest guest_nice
    read -r _ user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    local total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    local idle_total=$((idle + iowait))
    printf '%s\t%s\n' "$total" "$idle_total"
}

read_network_sample() {
    awk -F'[: ]+' 'NR > 2 {
        if ($1 == "lo") {
            next
        }
        rx += $3
        tx += $11
    }
    END {
        printf "%s\t%s\n", rx + 0, tx + 0
    }' /proc/net/dev
}

read_mem_value() {
    local key="$1"
    awk -v key="$key" '$1 == key ":" { print $2; exit }' /proc/meminfo
}

read_loadavg() {
    awk '{ printf "%s\t%s\t%s\n", $1, $2, $3 }' /proc/loadavg
}

read_uptime() {
    awk '{ printf "%s\n", int($1) }' /proc/uptime
}

read_hostname() {
    hostname 2>/dev/null || uname -n
}

read_kernel() {
    uname -sr
}

read_cpu_cores() {
    getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 1
}

read_top_process_cpu() {
    ps -eo comm=,pcpu=,pmem= --sort=-pcpu 2>/dev/null | awk 'NR == 1 { printf "%s\t%s\t%s\n", $1, $2, $3 }'
}

read_top_process_mem() {
    ps -eo comm=,rss=,pmem= --sort=-pmem 2>/dev/null | awk 'NR == 1 { printf "%s\t%s\t%s\n", $1, $2, $3 }'
}

read_disk_rows() {
    df -PT -B1 2>/dev/null | awk 'NR > 1 {
        fs = $1
        type = $2
        total = $3
        used = $4
        avail = $5
        percent = $6
        mount = $7
        for (i = 8; i <= NF; i++) {
            mount = mount " " $i
        }
        if (type ~ /^(tmpfs|devtmpfs|proc|sysfs|cgroup|cgroup2|efivarfs)$/) {
            next
        }
        if (mount ~ /^\/(proc|sys|run|dev)(\/|$)/) {
            next
        }
        if (percent !~ /^[0-9]+%$/) {
            next
        }
        gsub(/%/, "", percent)
        printf "%s\t%s\t%s\t%s\t%s\t%s\n", percent, mount, used, total, fs, type
    }' | sort -nr -k1,1 | head -n 4
}

read_state() {
    local timestamp total idle rx tx
    timestamp=0
    total=0
    idle=0
    rx=0
    tx=0

    if [[ -f "$STATE_FILE" ]]; then
        IFS=$'\t' read -r timestamp total idle rx tx < "$STATE_FILE" || true
    fi

    printf '%s\t%s\t%s\t%s\t%s\n' "$timestamp" "$total" "$idle" "$rx" "$tx"
}

write_state() {
    local timestamp="$1"
    local total="$2"
    local idle="$3"
    local rx="$4"
    local tx="$5"
    printf '%s\t%s\t%s\t%s\t%s\n' "$timestamp" "$total" "$idle" "$rx" "$tx" > "$STATE_FILE"
}

ensure_store

current_timestamp="$(date +%s)"
read -r previous_timestamp previous_cpu_total previous_cpu_idle previous_net_rx previous_net_tx < <(read_state)
read -r current_cpu_total current_cpu_idle < <(read_cpu_sample)
read -r current_net_rx current_net_tx < <(read_network_sample)

cpu_usage="0.0"
network_rx_rate="0"
network_tx_rate="0"

if (( previous_timestamp > 0 && current_timestamp > previous_timestamp )); then
    cpu_usage="$(awk -v total="$current_cpu_total" -v idle="$current_cpu_idle" -v prev_total="$previous_cpu_total" -v prev_idle="$previous_cpu_idle" 'BEGIN {
        delta_total = total - prev_total
        delta_idle = idle - prev_idle
        if (delta_total <= 0) {
            printf "0.0"
            exit
        }
        usage = 100 * (1 - (delta_idle / delta_total))
        if (usage < 0) {
            usage = 0
        }
        if (usage > 100) {
            usage = 100
        }
        printf "%.1f", usage
    }')"
    elapsed_seconds=$((current_timestamp - previous_timestamp))
    if (( elapsed_seconds > 0 )); then
        network_rx_rate="$(awk -v current="$current_net_rx" -v previous="$previous_net_rx" -v elapsed="$elapsed_seconds" 'BEGIN { delta = current - previous; if (delta < 0) delta = 0; printf "%.0f", delta / elapsed }')"
        network_tx_rate="$(awk -v current="$current_net_tx" -v previous="$previous_net_tx" -v elapsed="$elapsed_seconds" 'BEGIN { delta = current - previous; if (delta < 0) delta = 0; printf "%.0f", delta / elapsed }')"
    fi
fi

mem_total_kib="$(read_mem_value MemTotal)"
mem_available_kib="$(read_mem_value MemAvailable)"
swap_total_kib="$(read_mem_value SwapTotal)"
swap_free_kib="$(read_mem_value SwapFree)"

mem_used_kib=$((mem_total_kib - mem_available_kib))
if (( mem_used_kib < 0 )); then
    mem_used_kib=0
fi
mem_used_pct="$(awk -v used="$mem_used_kib" -v total="$mem_total_kib" 'BEGIN { if (total <= 0) { printf "0.0"; exit } printf "%.1f", (used / total) * 100 }')"

swap_used_kib=$((swap_total_kib - swap_free_kib))
if (( swap_used_kib < 0 )); then
    swap_used_kib=0
fi
swap_used_pct="$(awk -v used="$swap_used_kib" -v total="$swap_total_kib" 'BEGIN { if (total <= 0) { printf "0.0"; exit } printf "%.1f", (used / total) * 100 }')"

load1=""
load5=""
load15=""
read -r load1 load5 load15 < <(read_loadavg)

hostname_text="$(read_hostname)"
kernel_text="$(read_kernel)"
cores_text="$(read_cpu_cores)"
uptime_seconds="$(read_uptime)"
uptime_text="$(format_duration "$uptime_seconds")"

emit_center_row "System Monitor"
emit_row "Host" "$hostname_text"
emit_row "Kernel" "$kernel_text"
emit_row "Uptime" "$uptime_text"
emit_row "Load Avg" "$load1  $load5  $load15  (${cores_text} cores)"

cpu_meta=""
if [[ "$cpu_usage" =~ ^([0-9]+\.[0-9]+|[0-9]+)$ ]]; then
    cpu_usage_value="$cpu_usage"
else
    cpu_usage_value="0.0"
fi
cpu_percent_int="${cpu_usage_value%.*}"
if (( cpu_percent_int >= 90 )); then
    cpu_meta=" @meta:urgent=true"
fi
emit_row "CPU" "${cpu_usage_value}% of ${cores_text} cores" "$cpu_meta"

mem_meta=""
mem_percent_int="${mem_used_pct%.*}"
if (( mem_percent_int >= 90 )); then
    mem_meta=" @meta:urgent=true"
fi
emit_row "Memory" "$(human_bytes $((mem_used_kib * 1024))) / $(human_bytes $((mem_total_kib * 1024))) (${mem_used_pct}%)" "$mem_meta"

if (( swap_total_kib > 0 )); then
    swap_meta=""
    swap_percent_int="${swap_used_pct%.*}"
    if (( swap_percent_int >= 75 )); then
        swap_meta=" @meta:urgent=true"
    fi
    emit_row "Swap" "$(human_bytes $((swap_used_kib * 1024))) / $(human_bytes $((swap_total_kib * 1024))) (${swap_used_pct}%)" "$swap_meta"
fi

while IFS=$'\t' read -r percent mount used total fs type; do
    [[ -n "${percent:-}" ]] || continue
    disk_meta=""
    disk_percent_int="${percent%.*}"
    if (( disk_percent_int >= 90 )); then
        disk_meta=" @meta:urgent=true"
    fi
    emit_row "Disk ${mount}" "$(human_bytes "$used") / $(human_bytes "$total") (${percent}%)" "$disk_meta"
done < <(read_disk_rows)

if [[ -n "$current_net_rx" && -n "$current_net_tx" ]]; then
    emit_row "Network" "rx $(human_rate "$network_rx_rate")  tx $(human_rate "$network_tx_rate")"
fi

if top_cpu="$(read_top_process_cpu)"; then
    IFS=$'\t' read -r top_cpu_name top_cpu_percent top_cpu_mem <<< "$top_cpu"
    [[ -n "$top_cpu_name" ]] && emit_row "Top CPU" "${top_cpu_name}  ${top_cpu_percent}% CPU  ${top_cpu_mem}% MEM"
fi

if top_mem="$(read_top_process_mem)"; then
    IFS=$'\t' read -r top_mem_name top_mem_rss top_mem_percent <<< "$top_mem"
    if [[ -n "$top_mem_name" ]]; then
        top_mem_rss_bytes=$((top_mem_rss * 1024))
        emit_row "Top Memory" "${top_mem_name}  $(human_bytes "$top_mem_rss_bytes") RSS  ${top_mem_percent}% MEM"
    fi
fi

write_state "$current_timestamp" "$current_cpu_total" "$current_cpu_idle" "$current_net_rx" "$current_net_tx"
